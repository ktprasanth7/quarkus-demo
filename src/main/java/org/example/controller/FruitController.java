package org.example.controller;

import io.quarkus.hibernate.reactive.panache.common.WithTransaction;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import org.example.data.Fruit;
import org.example.service.FruitService;

import java.util.List;

@Path("/fruits")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class FruitController {

    @Inject
    FruitService service;

    @GET
    @WithTransaction
    public Uni<List<Fruit>> getAllFruits() {
        return service.listAll();
    }

    // TODO
    // How controllers defined in non blocking way -> Mutiny library can be used for creating and manipulating asynchronous data streams like below
    // @Nonblocking usage

    // Declarative way of coding -> We have lombok which reduces most boilerplate code
    // 1. @RestController and @RequestMapping -> @Route(path = "/hello")
    // 2. Mono and Flux in Spring reactive ->
    // Uni: Represents a single item or failure.
    // Multi: Represents a stream of items or failure.
    // 3. Handling transactions
    // @Transactional: Used for synchronous methods.
    // @WithTransaction: Used for reactive methods -> This ensures that your reactive operations are executed within a transactional context, enforcing the ACID properties and providing the necessary guarantees for data integrity and consistency. Without it, you risk partial updates, lack of rollback on failure, concurrent interference, and inconsistent state in your database.
    //   Transaction Initialization: The @WithTransaction annotation ensures that a transaction context is started before the method execution begins.
    //   Operation Execution: The operations entity.persist() and AnotherEntity.update("some-query") are executed within this transaction context.
    //   Context Propagation: The transaction context is propagated across the asynchronous operations managed by Uni, ensuring that all operations are part of the same transaction.
    //   Commit/Rollback: If any operation fails, the transaction will be rolled back. If all operations succeed, the transaction will be committed

    // Propagation and Isolation in reactive programming
    // Multi usage

    // Custom queries -> Implemented
    // Reactive way of coding -> Have to check some complex methods and their implementations.
    // Combine responses -> Objects A and B fetched and B should be combined in A using Reactive way. -> Done
    // Merging response and Querying usage

    // Person and Department Responses merging

    @GET
    @Path("/{id}")
    public Uni<Fruit> getFruit(@PathParam("id") Long id) {
        return service.getFruit(id);
    }

    @GET
    @Path("/{name}")
    public Uni<Fruit> getFruitByName(@PathParam("name") String name) {
        return service.getFruitByName(name);
    }

    @GET
    @Path("/{id}/{name}")
    public Uni<Fruit> getFruitByIdAndName(@PathParam("id") Long id, @PathParam("name") String name) {
        return service.findByIdAndName(id, name);
    }

    @POST
    public Uni<Fruit> createFruit(Fruit fruit) {
        return service.addFruit(fruit);
    }

    @PUT
    @Path("/{id}")
    public Uni<Fruit> updateFruit(@PathParam("id") Long id, Fruit Fruit) {
        return service.updateFruit(id, Fruit);
    }

    @DELETE
    @Path("/{id}")
    public Uni<Boolean> deleteFruit(@PathParam("id") Long id) {
        return service.deleteFruit(id);
    }


    @GET
    @Path("/chain/{name}")
    @Produces(MediaType.APPLICATION_JSON)
    public Uni<Fruit> chainMethods(@PathParam("name") String name) {
        return service.chainMethods(name);
    }
}
