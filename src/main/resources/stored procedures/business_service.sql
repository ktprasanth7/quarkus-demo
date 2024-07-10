-- FUNCTION: masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying)

-- DROP FUNCTION IF EXISTS masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying);

CREATE OR REPLACE FUNCTION masterdata.book_service(
	_card_number character varying,
	_service_type integer,
	_service_id uuid,
	_channel character varying,
	_tickets_slots json,
	_mobile bigint,
	_email character varying)
    RETURNS character varying
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
Declare
	 __user_id uuid;
	 __start_timestamp timestamptz;--common for event and classpack
	 __end_timestamp timestamptz;--common for event and classpack
	 __event_id uuid;
	 __class_id uuid;
	 __valid_booked_for_date date;
	 __booked_for_end_date date;
	 __booked_for_timestamp timestamptz;
	 __booked_for_date_classpack_ist date; --used for classpack IST calculation
	 __booked_for_time time with time zone; --used for future time comparison
	 __no_of_classes integer;
	 __booked_slots integer;
	 __confirmed_booking_status_id uuid;
	 __price_per_class numeric;--(15,2);
	 __incoming_no_of_classes integer;
	 __month_start_date date;
	 __month_end_date date;
	 __class_start_timestamp timestamptz;
	 __class_end_timestamp timestamptz;
	 __facility_id uuid;
	 __holidays_list_timestamp timestamptz[];
	 __holiday timestamptz;
	 __holidays_list date[];
	 __day_slot_id uuid;
	 __start_slot_timestamp timestamptz;--these columns in original table are without timestamp, make those columns with timezone
	 __end_slot_timestamp timestamptz;--these columns in original table are without timestamp, make those columns with timezone
     __start_slot_time timetz;--these columns in original table are without timestamp, make those columns with timezone
	 __end_slot_time timetz;--these columns in original table are without timestamp, make those columns with timezone
	 __ticket_slot_id uuid;
     __total_tickets_length integer;
     __ticket_counter integer;
     __total_participants_length integer;
     __participant_counter integer;
     __total_ques_ans_length integer;
     __ques_ans_counter integer;
	 __total_tickets integer;
	 __booked_tickets integer;
	 __ticket_max_participants integer;
	 __total_price numeric(15,2);
	 __total_accumulated_amount numeric(15,2);
	 __is_free boolean;
	 __order_id varchar;
	 ___booking_status_id uuid;
	 __booking_id uuid;
	 __booking_detail_id uuid;
	 __attendee_id uuid;
	 __mobile varchar;
	 __email varchar;
	 __status_id uuid;
	 __p_email varchar;
	 __p_mobile varchar;
	 __attendee_email varchar;
	 __attendee_mobile varchar;
     __participants_length integer;
     __tickets_length integer;
	 __participants_id uuid;
     ___ticket_counter integer;
     ___participant_counter integer;
	 __contactids character varying;
     __temp_order_id varchar;

	BEGIN
	__total_accumulated_amount := 0;

	--USER TABLE so it means user is booking the ticket
	select app_user_id into __user_id from userdata.app_usermaster where card_number = _card_number and is_active = true;

	if __user_id is not null then

		if _service_type = 1 then ---service type --> 1 = event
			-- [START] Restrict multiple booking for same user [START] --
			select status_id into __status_id from masterdata.verification_status_master where lower(status_name) = 'confirmed' and is_active = true;

                __tickets_length := json_array_length(_tickets_slots);
				--There should be atleast one ticket for booking
				if __tickets_length is not null and __tickets_length > 0 then
					FOR ___ticket_counter in  0..(__tickets_length -1)
					LOOP
					    __participants_length := json_array_length(_tickets_slots -> ___ticket_counter -> 'participants');
					    FOR ___participant_counter in  0..(__participants_length -1)
						LOOP
						    __participants_id = 	cast(_tickets_slots -> ___ticket_counter -> 'participants' -> ___participant_counter ->>'participant_id' as uuid);
							select email,mobile_no into __p_email, __p_mobile from userinfo.contacts where id = __participants_id and is_active = true;

							select c.email,c.mobile_no,ab.booking_id,abd.booking_detail_id,abp.afs_id into __attendee_email, __attendee_mobile  FROM masterdata.afs_bookings ab
							left outer join masterdata.afs_booking_details abd on ab.booking_id = abd.booking_id
							left outer join masterdata.afs_booking_participants abp on abd.booking_detail_id = abp.booking_detail_id
							left outer join userinfo.contacts c on c.id = abp.afs_id
							where ab.service_id = _service_id and ab.booking_status_id = __status_id and (c.email = __p_email or c.mobile_no = __p_mobile);

-- 							if __attendee_email is not null and __attendee_mobile is not null then
-- 								--__contactids :=concat(__contactids,'&~',concat('email: ', __attendee_email ,'', ' and mobile: ', __attendee_mobile));
-- 								__contactids :=concat(__contactids,'&~',concat(__attendee_email ,' and ', __attendee_mobile));

-- 							elsif __attendee_email is not null and __attendee_mobile is null then
-- 								--__contactids :=concat(__contactids,'&~',concat('email: ', __attendee_email));
-- 								__contactids :=concat(__contactids,'&~',concat(__attendee_email));

-- 							elsif __attendee_email is null and __attendee_mobile is not null then
-- 								--__contactids :=concat(__contactids,'&~',concat('mobile: ', __attendee_mobile));
-- 								__contactids :=concat(__contactids,'&~',concat(__attendee_mobile));

-- 							end if;
						END LOOP;
					END LOOP;
				end if;

					if __contactids is not null then
						return __contactids;
					end if;



			-- [END] Restrict multiple booking for single user [END] --

			select id , start_timestamp, end_timestamp into __event_id, __start_timestamp, __end_timestamp from public.event where id = _service_id and is_active = true and is_published = true and is_delete = false and is_draft = false;
			if __event_id is not null then
				__total_tickets_length := json_array_length(_tickets_slots);
				--There should be least one ticket for booking
				if __total_tickets_length is not null and __total_tickets_length > 0 then

				    -- This is to calculate the total accumulated amount for all the Line Items we have --
					FOR __ticket_counter in  0..(__total_tickets_length -1)
					LOOP
                        __ticket_slot_id:= cast(_tickets_slots->__ticket_counter ->>'ticket_slot_id' as uuid);

						if __end_timestamp - now() >= INTERVAL '0 DAY 00:00:00' then
							select total_tickets, booked_tickets, max_participants, total_price, is_free into __total_tickets, __booked_tickets, __ticket_max_participants, __total_price, __is_free
							from public.event_tickets where event_id = __event_id and id = __ticket_slot_id and is_active = true;

							if __total_tickets is not null and __ticket_max_participants is not null and __total_price is not null and __is_free is not null then

								if __booked_tickets is null then
									__booked_tickets:= 0;
								end if;

								__total_participants_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants');
								if __total_tickets - __booked_tickets >= __total_participants_length then
									if __total_participants_length <= __ticket_max_participants then
										if __is_free then
											__total_accumulated_amount := __total_accumulated_amount + 0;
										else
											__total_accumulated_amount := __total_accumulated_amount + (__total_price * __total_participants_length);
										end if;
									else
										return 'max_participants_exceeded_for_event_ticket';
									end if;
								else
									return 'insufficient_event_tickets';
								end if;
							else
								return 'invalid_event_ticket_id';
							end if;
						else
							return 'event_already_completed';
						end if;
					End LOOP;


                    -- Generating a new valid order_id for this booking order using SP named generate_unique_afs_order_id() --
					select userdata.generate_unique_afs_order_id() into __order_id;

					-- fetching the status_id for initialization from the table masterdata.verification_status_master so that we can save the status for this booking as initialized--
					select status_id into ___booking_status_id from masterdata.verification_status_master where lower(status_name) = 'initialized' and is_active = true;

                    -- create a new booking with following basic details order_id, user_id, service_type, service_id, booking_status_id, total_amount, channel, is_active, created_by, updated_by, mobile, email so that we will get a booking_id from it --
					insert into masterdata.afs_bookings (order_id, user_id, service_type, service_id, booking_status_id, total_amount, channel, is_active, created_by, updated_by, mobile, email)
					values (__order_id, __user_id, _service_type, _service_id, ___booking_status_id, __total_accumulated_amount, _channel, true, __user_id, __user_id, _mobile, _email) returning booking_id into __booking_id;

					-- if it returns a booking_id that means booking is successfully initialized else we return exception saying event_booking_failed--
					if __booking_id is not null then
					    -- As the booking is initialized, we will start saving all the booking details by iterating over LineItems just like we did when we are calculating total price --
						FOR __ticket_counter in  0..(__total_tickets_length -1)
						LOOP
						    -- fetching ticket_slot_id for this particular LineItem to check if tickets are available for this particular slot and for this particular event or not --
                            __ticket_slot_id:= cast(_tickets_slots->__ticket_counter ->>'ticket_slot_id' as uuid);

                            -- fetching total_price from public.event_tickets table based on event_id and slot_id
							select total_price into __total_price from public.event_tickets where event_id = __event_id and id = __ticket_slot_id and is_active = true;

                            -- fetching the total participants that this LineItem wants to book --
                            __total_participants_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants');

                            -- As we already checked we have the tickets for this event and this slot in the previous step of calculating price, we are directly proceeding with the saving of booking details --
                            -- booking_id, ticket_slot_id, booked_for, start_timestamp, end_timestamp, price_per_ticket_slot, total_participants, is_active, created_by, updated_by --
							insert into masterdata.afs_booking_details (booking_id, ticket_slot_id, booked_for, start_timestamp, end_timestamp, price_per_ticket_slot, total_participants, is_active, created_by, updated_by)
							values (__booking_id, __ticket_slot_id, date(__start_timestamp), __start_timestamp, __end_timestamp, __total_price, __total_participants_length , true, __user_id, __user_id) returning booking_detail_id into __booking_detail_id;

                            -- generate a temporary order_id using the SP userdata.generate_unique_temp_afs_order_id() --
                             select userdata.generate_unique_temp_afs_order_id() into __temp_order_id;

                            -- save these all details
                            insert into masterdata.temp_afs_bookings(temp_order_id,booking_id,booking_detail_id,ticket_slot_id,start_timestamp,end_timestamp,
                                                            is_active,created_by, updated_by)values(__temp_order_id,__booking_id,__booking_detail_id,__ticket_slot_id,
                                                                                                   __start_timestamp, __end_timestamp, true, __user_id, __user_id);

							FOR __participant_counter in  0..(__total_participants_length -1)
							LOOP
								insert into masterdata.afs_booking_participants (booking_detail_id, afs_id, is_active, created_by, updated_by)
								values (__booking_detail_id, cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter ->>'participant_id' as uuid),
                                true, __user_id, __user_id) returning attendee_id into __attendee_id;

                                __total_ques_ans_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter ->'question_answer');

                                if __total_ques_ans_length is not null and  __total_ques_ans_length > 0 then
                                    FOR __ques_ans_counter in 0..(__total_ques_ans_length -1 )
                                    LOOP
                                        insert into masterdata.afs_booking_ques_ans_responses (booking_detail_id, attendee_id, question_id, answer_id, is_active, created_by, updated_by)
                                        values (__booking_detail_id, __attendee_id, cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter -> 'question_answer'-> __ques_ans_counter ->>'question_id' as uuid),
                                        cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter -> 'question_answer'-> __ques_ans_counter ->>'answer_id' as uuid), true, __user_id, __user_id);
                                    END LOOP;
                                end if;
							END LOOP;
						End LOOP;

                        insert into masterdata.is_afs_user_rated(booking_id, order_id, service_id, service_type, user_id, email, is_popup, is_popup_valid, is_rated, service_end_timestamp, is_active, created_by, updated_by)
                        values(__booking_id, __order_id, _service_id, _service_type, __user_id, _email , true, true, false, __end_timestamp, true, __user_id, __user_id);

						RETURN concat(__total_accumulated_amount,',', __order_id,',', __booking_id,',',__temp_order_id);

					else
						return 'event_booking_failed';
					end if;
				else
					RETURN 'atleast_one_ticket_is_required';
				end if;
			else
				RETURN 'invalid_event_id';
			end if;

		--------- CLASS BOOKING / COACHING BOOKING ---------------
		-- TIMESTAMP WITH TIME ZONE
		elsif _service_type = 2 then ---service type --> 2 = class
			select id, date_trunc('seconds', start_timestamp), date_trunc('seconds', end_timestamp) into __class_id, __start_timestamp, __end_timestamp from public.class
			where id = _service_id and is_active = true and is_published = true and is_delete = false and is_draft = false;
			if __class_id is not null then
				__total_tickets_length := json_array_length(_tickets_slots);
				--There should be atleast one slot for booking
				if __total_tickets_length is not null and __total_tickets_length > 0 then

					select status_id into __confirmed_booking_status_id from masterdata.verification_status_master where lower(status_name) = 'confirmed' and is_active = true;

					FOR __ticket_counter in  0..(__total_tickets_length -1)
					LOOP
                        __ticket_slot_id := cast(_tickets_slots->__ticket_counter ->>'ticket_slot_id' as uuid);
						__booked_for_timestamp := cast(_tickets_slots->__ticket_counter ->>'booked_for' as timestamp with time zone);

						-- removing the milliseconds part from the incoming __booked_for_timestamp just to be 100% assured while comparing other timestamps
						__booked_for_timestamp := date_trunc('seconds',__booked_for_timestamp);

						if __booked_for_timestamp >= __start_timestamp then
							if (__booked_for_timestamp - date_trunc('seconds',current_timestamp)) >= INTERVAL '-00:05:00' then --allowing to book tickets for the same day upto past 5 minutes
								--if the class has an optional end date then booked_for field in booking cannot exceed the end date of the class
								if __end_timestamp is not null and __booked_for_timestamp > __end_timestamp then
									return 'class_is_completed';
								end if;

								select total_tickets, max_participants, total_price, is_free into
								__total_tickets, __ticket_max_participants, __total_price, __is_free
								from public.class_tickets where class_id = __class_id and id = __ticket_slot_id and is_active = true;

								-- getting no of classes for that month

								select count(*)  into __no_of_classes FROM generate_series(date_trunc('month', __booked_for_timestamp::timestamp),
								date_trunc('month',__booked_for_timestamp::timestamp) + '1 month'::interval - '1 day'::interval,'1 day'::interval) gs(d)
								WHERE extract(DOW FROM gs.d) IN (select day from public.class_day_slots where class_id = __class_id and is_active = true);



								__valid_booked_for_date := date_trunc('day', __booked_for_timestamp)::date;

								__booked_for_time := __booked_for_timestamp::time with time zone;

								----- This logic states that whenever the time is greater than 18:29:59 and less than 23:59:59,
								----- then the __valid_booked_for_date has to be increased by 1 day as it refers to next day as per IST format
								if __booked_for_time > '18:29:59+00:00' and __booked_for_time < '23:59:59+00:00' then
									__valid_booked_for_date := __valid_booked_for_date + integer '1';
								end if;

								--### this field is required for calculating the no of confirmed bookings for that month of the class
								__month_start_date:= date_trunc('month', __valid_booked_for_date)::date;

								--### this field is required for calculating the no of confirmed bookings for that month of the class
								-- __month_end_date:= (date_trunc('month', __month_start_date) + interval '1 month - 1 day')::date;
								-- 25/02/2022 karthik
								if __end_timestamp is not null then
									if ((SELECT EXTRACT(Month FROM  __month_start_date))= (SELECT EXTRACT(Month FROM  __end_timestamp)))
										and ((SELECT EXTRACT(Year FROM  __month_start_date))= (SELECT EXTRACT(Year FROM  __end_timestamp)))
										then
											__month_end_date:=__end_timestamp::date;

									else
 										__month_end_date:= (date_trunc('month', __month_start_date) + interval '1 month - 1 day')::date;
									end if;
								else
 									__month_end_date:= (date_trunc('month', __month_start_date) + interval '1 month - 1 day')::date;

								end if;

								-- If we got time greater than 18:29:59 and less than 23:59:59 then we will check for booked_slots for next month
								-- as now booked_for field contains IST date for this condition and also we have increased a day in __valid_booked_for_date
								select sum(total_participants) into __booked_slots from masterdata.afs_booking_details where booking_id in
								(select booking_id from masterdata.afs_bookings where service_id = __class_id and service_type = 2 and
								booking_status_id = __confirmed_booking_status_id and is_active = true) and is_active = true and
								booked_for BETWEEN __month_start_date AND __month_end_date ;

								if __total_tickets is not null and __no_of_classes is not null and __total_price is not null and __is_free is not null then
									if __booked_slots is null then
										__booked_slots:= 0;
									end if;
									if __ticket_max_participants is null then
										__ticket_max_participants:= 5; --default max particpants is 5 for class booking
									end if;



									select count(the_day) into __incoming_no_of_classes from (select generate_series(__valid_booked_for_date, __month_end_date, '1 day') as the_day) days
									where extract('dow' from the_day) in (select day from public.class_day_slots where class_id = __class_id and is_active = true);

									if __incoming_no_of_classes > 0 then
										--if it is greater than zero then only it is allowed to be created
										if __incoming_no_of_classes > __no_of_classes then
										--if in some months the __incoming_no_of_classes is greater than __no_of_classes then make the __incoming_no_of_classes equal to __no_of_classes
											__incoming_no_of_classes:= __no_of_classes;
										end if;
									else
										return 'invalid_no_of_classes';
									end if;

									__total_participants_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants');

									if __total_tickets - __booked_slots >= __total_participants_length then
										if __ticket_max_participants is not null and __total_participants_length <= __ticket_max_participants then
											if __is_free then
												__total_accumulated_amount := __total_accumulated_amount + 0;
											else
												__price_per_class:= __total_price/__no_of_classes; --round(__total_price/__no_of_classes,2);
												--__total_accumulated_amount := __total_accumulated_amount + (__price_per_class * __incoming_no_of_classes * __total_participants_length);
											 	__total_accumulated_amount := __total_accumulated_amount + (__total_price * __total_participants_length);

											end if;
										else
											return 'max_participants_exceeded_for_class_slot';
										end if;
									else
										return 'insufficient_slots_in_class';
									end if;
								else
									return 'invalid_class_slot_id';
								end if;
							else
								return 'booked_for_date_cannot_be_past';
							end if;
						else
							return 'class_not_started';
						end if;
					End LOOP;

					select userdata.generate_unique_afs_order_id() into __order_id;
					select status_id into ___booking_status_id from masterdata.verification_status_master where lower(status_name) = 'initialized' and is_active = true;

					insert into masterdata.afs_bookings (order_id, user_id, service_type, service_id, booking_status_id, total_amount, channel, is_active, created_by, updated_by, mobile, email)
					values (__order_id, __user_id, _service_type, _service_id, ___booking_status_id, __total_accumulated_amount, _channel, true, __user_id, __user_id, _mobile, _email)
					returning booking_id into __booking_id;

					if __booking_id is not null then
						FOR __ticket_counter in  0..(__total_tickets_length -1)
						LOOP
                            __ticket_slot_id:= cast(_tickets_slots->__ticket_counter ->>'ticket_slot_id' as uuid);

							__booked_for_timestamp := cast(_tickets_slots->__ticket_counter ->>'booked_for' as timestamp with time zone);

							-- removing the milliseconds part from the incoming __booked_for_timestamp just to be 100% assured while comparing other timestamps
							__booked_for_timestamp := date_trunc('seconds',__booked_for_timestamp);

							__valid_booked_for_date := date_trunc('day', __booked_for_timestamp)::date;

							__booked_for_time := __booked_for_timestamp::time with time zone;

							----- This logic states that whenever the time is greater than 18:29:59 and less than 23:59:59,
							----- then the __valid_booked_for_date has to be increased by 1 day as it refers to next day as per IST format
							if __booked_for_time > '18:29:59+00:00' and __booked_for_time < '23:59:59+00:00' then
								__valid_booked_for_date := __valid_booked_for_date + integer '1';
							end if;

								-- 25/02/2022 karthik
							--__month_end_date:= (date_trunc('month', __valid_booked_for_date) + interval '1 month - 1 day')::date;
							if __end_timestamp is not null then
									if ((SELECT EXTRACT(Month FROM  __valid_booked_for_date))= (SELECT EXTRACT(Month FROM  __end_timestamp)))
										and ((SELECT EXTRACT(Year FROM  __valid_booked_for_date))= (SELECT EXTRACT(Year FROM  __end_timestamp)))
										then
											__month_end_date:=__end_timestamp::date;

									else
										__month_end_date:= (date_trunc('month', __valid_booked_for_date) + interval '1 month - 1 day')::date;

									end if;
						else
								__month_end_date:= (date_trunc('month', __valid_booked_for_date) + interval '1 month - 1 day')::date;
							end if;

							select count(the_day) into __incoming_no_of_classes from (select generate_series(__valid_booked_for_date, __month_end_date, '1 day') as the_day) days
							where extract('dow' from the_day) in (select day from public.class_day_slots where class_id = __class_id and is_active = true);

							select  total_price into  __total_price
							from public.class_tickets where class_id = __class_id and id = __ticket_slot_id and is_active = true;

							-- for getting number of classes


								select count(*)  into __no_of_classes FROM generate_series(date_trunc('month', __booked_for_timestamp::timestamp),
								date_trunc('month',__booked_for_timestamp::timestamp) + '1 month'::interval - '1 day'::interval,'1 day'::interval) gs(d)
								WHERE extract(DOW FROM gs.d) IN (select day from public.class_day_slots where class_id = __class_id and is_active = true);

                            __total_participants_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants');

							-- __price_per_class:= round(__total_price/__no_of_classes,2);
                            __price_per_class:= __total_price/__no_of_classes;



							if __incoming_no_of_classes > __no_of_classes then
							--if in some months the __incoming_no_of_classes is greater than __no_of_classes then make the __incoming_no_of_classes equal to __no_of_classes
								__incoming_no_of_classes:= __no_of_classes;
							end if;
                            -- __price_per_class:= round(__total_price/__no_of_classes,2);
                            __price_per_class:= __total_price/__incoming_no_of_classes;

							select the_day into __class_start_timestamp from (select generate_series(__valid_booked_for_date, __month_end_date, '1 day') as the_day) days
							where extract('dow' from the_day) in (select day from public.class_day_slots where class_id = __class_id and is_active = true) limit 1;

							select the_day into __class_end_timestamp from (select generate_series(__month_end_date, __valid_booked_for_date, '-1 day') as the_day) days
							where extract('dow' from the_day) in (select day from public.class_day_slots where class_id = __class_id and is_active = true) limit 1;

							-- For classpack booking the booked_for depicts the IST date to keep consistency while calculating booked_slots of classpack
							__booked_for_date_classpack_ist := __class_start_timestamp::date;

							if __booked_for_time > '18:29:59+00:00' and __booked_for_time < '23:59:59+00:00' then
								__class_start_timestamp := __class_start_timestamp - interval '5 hours 30 minutes';
							end if;

							insert into masterdata.afs_booking_details (booking_id, ticket_slot_id, no_of_classes, booked_for, start_timestamp, end_timestamp, price_per_ticket_slot, total_participants, is_active, created_by, updated_by)
							values (__booking_id, __ticket_slot_id, __incoming_no_of_classes, __booked_for_date_classpack_ist , __class_start_timestamp, (date(__class_end_timestamp) + timetz'18:29:59'), __price_per_class, __total_participants_length ,
							true, __user_id, __user_id) returning booking_detail_id into __booking_detail_id;

                            select userdata.generate_unique_temp_afs_order_id() into __temp_order_id;

                            insert into masterdata.temp_afs_bookings(temp_order_id,booking_id,booking_detail_id,ticket_slot_id,start_timestamp,end_timestamp,
                                                            is_active,created_by, updated_by)values(__temp_order_id,__booking_id,__booking_detail_id,__ticket_slot_id,
                                                                                                   __class_start_timestamp, (date(__class_end_timestamp) + timetz'18:29:59'), true, __user_id, __user_id);


							FOR __participant_counter in  0..(__total_participants_length -1)
							LOOP
								insert into masterdata.afs_booking_participants (booking_detail_id, afs_id, is_active, created_by, updated_by)
								values (__booking_detail_id, cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter ->> 'participant_id' as uuid),
                                true, __user_id, __user_id) returning attendee_id into __attendee_id;

                                __total_ques_ans_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter ->'question_answer');

                                if __total_ques_ans_length is not null and  __total_ques_ans_length > 0 then
                                    FOR __ques_ans_counter in 0..(__total_ques_ans_length -1 )
                                    LOOP
                                        insert into masterdata.afs_booking_ques_ans_responses (booking_detail_id, attendee_id, question_id, answer_id, is_active, created_by, updated_by)
                                        values (__booking_detail_id, __attendee_id, cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter -> 'question_answer'-> __ques_ans_counter ->>'question_id' as uuid),
                                        cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter -> 'question_answer'-> __ques_ans_counter ->>'answer_id' as uuid), true, __user_id, __user_id);
                                    END LOOP;
                                end if;
							END LOOP;
						End LOOP;

						insert into masterdata.is_afs_user_rated(booking_id, order_id, service_id, service_type, user_id, email, is_popup, is_popup_valid, is_rated, service_end_timestamp, is_active, created_by, updated_by)
                        values(__booking_id, __order_id, _service_id, _service_type, __user_id, _email , true, true, false, (date(__class_end_timestamp) + timetz'18:29:59'),  true, __user_id, __user_id);

						RETURN concat(__total_accumulated_amount,',', __order_id,',', __booking_id,',',__temp_order_id);

					else
						return 'class_booking_failed';
					end if;
				else
					RETURN 'atleast_one_slot_is_required';
				end if;
			else
				RETURN 'invalid_class_id';
			end if;
		--FACILITY BOOKING WITH UPADTED TIMESTAMP WITH TIME ZONE COLUMNS
		elsif _service_type = 3 then ---service type --> 3 = facility
			select id, holidays into __facility_id, __holidays_list_timestamp from public.facility where id = _service_id
			and is_active = true and is_published = true and is_delete = false and is_draft = false;

			if __facility_id is not null then
				__total_tickets_length := json_array_length(_tickets_slots);
				--There should be atleast one slot for booking
				if __total_tickets_length is not null and __total_tickets_length > 0 then

					select status_id into __confirmed_booking_status_id from masterdata.verification_status_master where lower(status_name) = 'confirmed' and is_active = true;

					FOR __ticket_counter in  0..(__total_tickets_length -1)
					LOOP
                        __ticket_slot_id:= cast(_tickets_slots->__ticket_counter ->>'ticket_slot_id' as uuid);
						__booked_for_timestamp := cast(_tickets_slots->__ticket_counter ->>'booked_for' as timestamp with time zone);
						-- removing the milliseconds part from the incoming __booked_for_timestamp just to be 100% assured while comparing other timestamps
						__booked_for_timestamp := date_trunc('seconds',__booked_for_timestamp);
						__valid_booked_for_date := __booked_for_timestamp::date;

						if (__booked_for_timestamp - date_trunc('seconds',current_timestamp)) >= INTERVAL '-00:05:00' then --allowing to book tickets for the same day upto past 5 minutes

							__booked_for_time := __booked_for_timestamp::time with time zone;

							----- This logic states that whenever the time is greater than 18:29:59 and less than 23:59:59,
							----- then the __valid_booked_for_date has to be increased by 1 day as it refers to next day as per IST format
							if __booked_for_time > '18:29:59+00:00' and __booked_for_time < '23:59:59+00:00' then
								__valid_booked_for_date := __valid_booked_for_date + integer '1';
							end if;

							if __holidays_list_timestamp is not null then
								FOREACH __holiday in ARRAY __holidays_list_timestamp
								LOOP
									__holidays_list := array_append(__holidays_list , date_trunc('day', __holiday)::date);
								END LOOP;
								if __valid_booked_for_date = ANY(__holidays_list) then
									return 'facility_is_unavailable';
								end if;
							end if;


							select day_slot_id into __day_slot_id from public.facility_day_slots where day
							in (select extract('dow' from __valid_booked_for_date)) and facility_id =  __facility_id and is_active = true;

							if __day_slot_id is not null then
								select date_trunc('seconds', start_slot_time), date_trunc('seconds', end_slot_time), total_price, is_free into __start_slot_timestamp, __end_slot_timestamp, __total_price, __is_free
								from public.facility_time_slots where day_slot_id = __day_slot_id and time_slot_id = __ticket_slot_id and is_active = true;

								if __start_slot_timestamp is not null and __end_slot_timestamp is not null and __is_free is not null and __total_price is not null then
									__start_slot_time := cast(__start_slot_timestamp as time with time zone);

									-- the __valid_booked_for_date is being reinitialised because whether the date is future(from 18:29:59 to 23:59:59) or current the booking table will have the booked_for date column as the date extracted from __booked_for_timestamp only which is UTC date
									__valid_booked_for_date := __booked_for_timestamp::date;

									--now the booked_for timestamp field must have the start_slot_time coming from the tickets api for that particular time_slot and hence both must match to proceed further
									-- allowing to book tickets for the same day upto past 5 minutes
									if ((__valid_booked_for_date + __start_slot_time) - date_trunc('seconds',current_timestamp)) >= INTERVAL '-00:05:00' and __booked_for_time = __start_slot_time then
										select count(total_participants) into __booked_slots from masterdata.afs_booking_details where booking_id in
										(select booking_id from masterdata.afs_bookings where service_id = __facility_id and service_type = 3 and
										booking_status_id = __confirmed_booking_status_id and is_active = true) and is_active = true and
										booked_for = __valid_booked_for_date and ticket_slot_id = __ticket_slot_id;

										if __booked_slots is not null and __booked_slots = 0 then

											__total_participants_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants');

											if __total_participants_length is not null and __total_participants_length = 1 then
												if __is_free then
													__total_accumulated_amount := __total_accumulated_amount + 0;
												else
													__total_accumulated_amount := __total_accumulated_amount + (__total_price * __total_participants_length);
												end if;
											else
												return 'only_one_participant_is_allowed';
											end if;
										else
											return 'slot_is_already_booked';
										end if;
									else
										return 'booked_for_date_cannot_be_past';
									end if;
								else
									return 'invalid_facility_time_slot_id';
								end if;
							else
								return 'invalid_booked_for_date_for_this_facility';
							end if;
						else
							return 'booked_for_date_cannot_be_past';
						end if;
					End LOOP;

					select userdata.generate_unique_afs_order_id() into __order_id;
					select status_id into ___booking_status_id from masterdata.verification_status_master where lower(status_name) = 'initialized' and is_active = true;

					insert into masterdata.afs_bookings (order_id, user_id, service_type, service_id, booking_status_id, total_amount, channel, is_active, created_by, updated_by, mobile, email)
					values (__order_id, __user_id, _service_type, _service_id, ___booking_status_id, __total_accumulated_amount, _channel, true, __user_id, __user_id, _mobile, _email)
					returning booking_id into __booking_id;


					if __booking_id is not null then
						FOR __ticket_counter in  0..(__total_tickets_length -1)
						LOOP
                            __ticket_slot_id:= cast(_tickets_slots->__ticket_counter ->>'ticket_slot_id' as uuid);

							__booked_for_timestamp := cast(_tickets_slots->__ticket_counter ->>'booked_for' as timestamp with time zone);

							-- removing the milliseconds part from the incoming __booked_for_timestamp just to be 100% assured while comparing other timestamps
							__booked_for_timestamp := date_trunc('seconds',__booked_for_timestamp);

							__valid_booked_for_date := __booked_for_timestamp::date;

							select date_trunc('seconds', start_slot_time), date_trunc('seconds', end_slot_time), total_price into __start_slot_timestamp, __end_slot_timestamp, __total_price
							from public.facility_time_slots where time_slot_id = __ticket_slot_id and is_active = true;

							--when the end_slot_time is in another day as compared to the start_slot_time
							if date(__end_slot_timestamp) - date(__start_slot_timestamp) > 0 then
								__booked_for_end_date := __valid_booked_for_date + integer '1';
							else
								__booked_for_end_date := __valid_booked_for_date;
							end if;

							__start_slot_time := cast(__start_slot_timestamp as time with time zone);
							__end_slot_time := cast(__end_slot_timestamp as time with time zone);

                            __total_participants_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants');
							--in case of facility booking each slot has its own price and currently we can have max of only 1 particpant hence the price_per_ticket_slot column of afs_booking_details would contain the total_price of that time slot
							insert into masterdata.afs_booking_details (booking_id, ticket_slot_id, booked_for, start_timestamp, end_timestamp, price_per_ticket_slot, total_participants, is_active, created_by, updated_by)
							values (__booking_id, __ticket_slot_id, __valid_booked_for_date, (__valid_booked_for_date + __start_slot_time), (__booked_for_end_date + __end_slot_time), __total_price, __total_participants_length , true, __user_id, __user_id)
							returning booking_detail_id into __booking_detail_id;

                            select userdata.generate_unique_temp_afs_order_id() into __temp_order_id;

                             insert into masterdata.temp_afs_bookings(temp_order_id,booking_id,booking_detail_id,ticket_slot_id,start_timestamp,end_timestamp,
                                                            is_active,created_by, updated_by)values(__temp_order_id,__booking_id,__booking_detail_id,__ticket_slot_id,
                                                                                                   (__valid_booked_for_date + __start_slot_time), (__booked_for_end_date + __end_slot_time), true, __user_id, __user_id);

							FOR __participant_counter in  0..(__total_participants_length -1)
							LOOP
								insert into masterdata.afs_booking_participants (booking_detail_id, afs_id, is_active, created_by, updated_by)
								values (__booking_detail_id, cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter ->>'participant_id' as uuid),
                                true, __user_id, __user_id) returning attendee_id into __attendee_id;

                                __total_ques_ans_length := json_array_length(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter ->'question_answer');

                                if __total_ques_ans_length is not null and  __total_ques_ans_length > 0 then
                                    FOR __ques_ans_counter in 0..(__total_ques_ans_length -1 )
                                    LOOP
                                        insert into masterdata.afs_booking_ques_ans_responses (booking_detail_id, attendee_id, question_id, answer_id, is_active, created_by, updated_by)
                                        values (__booking_detail_id, __attendee_id, cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter -> 'question_answer'-> __ques_ans_counter ->>'question_id' as uuid),
                                        cast(_tickets_slots -> __ticket_counter -> 'participants' -> __participant_counter -> 'question_answer'-> __ques_ans_counter ->>'answer_id' as uuid), true, __user_id, __user_id);
                                    END LOOP;
                                end if;
							END LOOP;
						End LOOP;

						insert into masterdata.is_afs_user_rated(booking_id, order_id, service_id, service_type, user_id, email, is_popup, is_popup_valid, is_rated, is_active, created_by, updated_by)
                        values(__booking_id, __order_id, _service_id, _service_type, __user_id, _email , true, true, false, true, __user_id, __user_id);


						RETURN concat(__total_accumulated_amount,',', __order_id,',', __booking_id,',',__temp_order_id);

					else
						return 'facility_booking_failed';
					end if;
				else
					RETURN 'atleast_one_slot_is_required';
				end if;
			else
				RETURN 'invalid_facility_id';
			end if;
		else
			RETURN 'invalid_service_type';
		end if;
	else
		RETURN 'invalid_user';
	end if;

--   	EXCEPTION WHEN others THEN
--         	insert into userdata.error_log_table (function_name, error_code, error_msg, card_number, other_info) values ('masterdata.book_service', SQLSTATE, SQLERRM, _card_number, _service_id);
--       RETURN 'failure';
    END;
$BODY$;

ALTER FUNCTION masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying)
    OWNER TO app_dplatform;

GRANT EXECUTE ON FUNCTION masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying) TO PUBLIC;

GRANT EXECUTE ON FUNCTION masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying) TO app_dplatform;

GRANT EXECUTE ON FUNCTION masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying) TO gp_func_access;

GRANT EXECUTE ON FUNCTION masterdata.book_service(character varying, integer, uuid, character varying, json, bigint, character varying) TO z22mnara;

