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

    @GET
    @Path("/{id}")
    @WithTransaction
    public Uni<Fruit> getFruit(@PathParam("id") Long id) {
        return service.getFruit(id);
    }

    @POST
    @WithTransaction
    public Uni<Fruit> createFruit(Fruit fruit) {
        return service.addFruit(fruit);
    }

    @PUT
    @Path("/{id}")
    @WithTransaction
    public Uni<Fruit> updateFruit(@PathParam("id") Long id, Fruit Fruit) {
        return service.updateFruit(id, Fruit);
    }

    @DELETE
    @Path("/{id}")
    @WithTransaction
    public Uni<Boolean> deleteFruit(@PathParam("id") Long id) {
        return service.deleteFruit(id);
    }

}
