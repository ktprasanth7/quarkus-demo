package org.example.service;

import io.quarkus.hibernate.reactive.panache.common.WithTransaction;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import lombok.extern.slf4j.Slf4j;
import org.example.data.Fruit;
import org.example.data.FruitBox;
import org.example.data.Shop;
import org.example.repository.FruitBoxRepository;
import org.example.repository.FruitRepository;
import org.example.repository.ShopRepository;
import org.example.request.AddFruitToBoxRequest;
import org.example.response.AddFruitToBoxResponse;
import org.hibernate.Hibernate;
import org.hibernate.reactive.mutiny.Mutiny;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

@ApplicationScoped
@Slf4j
public class FruitService {

    @Inject
    FruitRepository fruitRepository;

    @Inject
    FruitBoxRepository fruitBoxRepository;

    @Inject
    ShopRepository shopRepository;

    @WithTransaction
    public Uni<List<Fruit>> listAll() {
        return fruitRepository.listAll();
    }

    @WithTransaction
    public Uni<List<FruitBox>> listAllBoxes() {
        return fruitBoxRepository.listAll();
    }

    @WithTransaction
    public Uni<Fruit> getFruit(Long id) {
        return fruitRepository.findById(id);
    }

    @WithTransaction
    public Uni<Fruit> addFruit(Fruit fruit) {
//        return fruitRepository.persist(fruit).replaceWith(fruit);
        if(Objects.nonNull(fruitRepository.findByName(fruit.getName()))) {
            return fruitRepository.findByName(fruit.getName());
        }
        return fruitRepository.persist(fruit);
    }

    @WithTransaction
    public Uni<Fruit> updateFruit(Long id, Fruit fruit) {
        return fruitRepository.findById(id)
                .onItem().ifNotNull().invoke(entity -> {
                    entity.name = fruit.name;
                    entity.color = fruit.color;
                    entity.price = fruit.price;
                });
    }

    @WithTransaction
    public Uni<Boolean> deleteFruit(Long id) {
        return fruitRepository.deleteById(id);
    }

    @WithTransaction
    public Uni<Fruit> getFruitByName(String name) {
        String nativeQuery =  "select * from fruit where name = :name";

        return fruitRepository.getSession()
                .onItem()
                .transformToUni(session ->
                        session.createNativeQuery(nativeQuery, Fruit.class)
                                .setParameter("name", name)
                                .getSingleResult());
    }

    @WithTransaction
    public Uni<Fruit> findByIdAndName(Long id, String name) {
        return fruitRepository.findByIdAndName(id, name);
    }

    @WithTransaction
    public Uni<Fruit> chainMethods(String name) {
        return listAll() // First Method Call
                .flatMap(responseFromFirst -> responseFromFirst.stream()
                        .filter(fruit -> name.equals(fruit.getName()))
                        .findFirst()
                        .map(fruit -> getFruitByName(fruit.getName())) // Second Method Call
                        .orElse(Uni.createFrom().failure(new RuntimeException(name + " fruit not found"))))
                .onItem().transformToUni(responseFromSecond -> Uni.createFrom().item(responseFromSecond));
    }

    @WithTransaction
    public Uni<FruitBox> createFruitBox(FruitBox fruitBox) {
        return fruitBoxRepository.persist(fruitBox);
    }

    @WithTransaction
    public Uni<FruitBox> getFruitBoxById(Long id) {
        return fruitBoxRepository.findById(id);
    }

    // Why only flatMap for calling other methods?
    // Map ->
    //  When you need to apply a simple transformation to each item.
    //  When the operation is synchronous and doesn't involve additional asynchronous computations or reactive streams.
    //
    // Flatmap ->
    //  When the transformation involves asynchronous operations.
    //  When you need to handle each item by returning another reactive stream (e.g., making HTTP calls, database queries).

    @WithTransaction
    public Uni<AddFruitToBoxResponse> addFruitToBox(AddFruitToBoxRequest request) {

        return getFruitBoxById(request.getBoxId()) // First Method Call
                .onItem().invoke(fruitBox -> {
                    // Check if the fruitList is initialized before fetching
                    if (Hibernate.isInitialized(fruitBox.getFruitList())) {
                        log.info("Fruit list is already initialized.");
                    } else {
                        log.info("Fruit list is not initialized.");
                    }
                })
                .flatMap(fruitBox -> Mutiny.fetch(fruitBox.getFruitList()) // Fetch the lazy-loaded fruitList
                        .flatMap(fruitList -> addFruit(request.getFruit()) // Second Method Call
                                .flatMap(fruit -> {
                                    // Add the fruit to the fruit box
                                    fruitList.add(fruit);
                                    fruitBox.setQuantity(fruitBox.getQuantity() + request.getQuantity());

                                    // Persist the fruit box reactively
                                    return fruitBoxRepository.persist(fruitBox)
                                            .map(persistedFruitBox -> {
                                                // Create response after persistence
                                                AddFruitToBoxResponse response = new AddFruitToBoxResponse();
                                                response.setId(persistedFruitBox.getId());

                                                ArrayList<Fruit> fruits = new ArrayList<>();
                                                fruits.add(fruit);
                                                response.setFruitTypes(fruits);
                                                response.setDescription(fruitBox.getDescription());
                                                response.setBoxPrice(persistedFruitBox.getBoxPrice());
                                                response.setQuantity(persistedFruitBox.getQuantity());
                                                response.setStatus("Fruit added to box successfully!");

                                                return response;
                                            });
                                })
                        )
                );

        /*

        return getFruitBoxById(request.getBoxId()) // First Method Call
                .onItem().invoke(fruitBox -> {
                    // Check if the fruitList is initialized
                    try {
                        log.info("Fruits in the box {}", new ObjectMapper().writeValueAsString(fruitBox));
                    } catch (JsonProcessingException e) {
                        throw new RuntimeException(e);
                    }
                    if (Hibernate.isInitialized(fruitBox.getFruitList())) {
                        System.out.println("Fruit list is initialized.");
                    } else {
                        System.out.println("Fruit list is not initialized.");
                    }
                })
                .flatMap(fruitBox -> addFruit(request.getFruit()) // Second Method Call
                        .flatMap(fruit -> {
                            // Add the fruit to the fruit box
                            fruitBox.getFruitList().add(fruit);

                            // Persist the fruit box reactively
                            return fruitBoxRepository.persist(fruitBox)
                                    .map(fruitBox1 -> {
                                        // Create response after persistence
                                        AddFruitToBoxResponse response = new AddFruitToBoxResponse();
                                        response.setId(fruitBox.getId());

                                        ArrayList<Fruit> fruits = new ArrayList<>();
                                        fruits.add(fruit);
                                        response.setFruitTypes(fruits);
                                        response.setDescription("Fruit added to box successfully!");
                                        response.setBoxPrice(fruitBox.getBoxPrice());
                                        response.setQuantity(fruitBox.getQuantity());

                                        return response;
                                    });
                        })
                );
        */

    }

    @WithTransaction
    public Uni<AddFruitToBoxResponse> addFruitsToBox(AddFruitToBoxRequest request) {
        return getFruitBoxById(request.getBoxId()) // First Method Call
                .flatMap(fruitBox -> addFruit(request.getFruit()) // Second Method Call
                        .flatMap(fruit -> {
                            // Here you can alter the response or combine the results
                            AddFruitToBoxResponse response = new AddFruitToBoxResponse();
                            response.setId(fruitBox.getId());

                            ArrayList<Fruit> fruits = new ArrayList<>();
                            fruits.add(fruit);
                            response.setFruitTypes(fruits);
                            response.setDescription(fruitBox.getDescription());
                            response.setBoxPrice(fruitBox.getBoxPrice());
                            response.setQuantity(fruitBox.getQuantity());
                            return Uni.createFrom().item(response);
                        })
                );
    }

    @WithTransaction
    public Uni<Shop> createShop() {
        return listAllBoxes().flatMap(fruitBoxes -> {
            // Initialize fruitBoxes eagerly within the transactional context
            Mutiny.fetch(fruitBoxes);
            fruitBoxes.size(); // This forces Hibernate to initialize the collection

            Shop newShop = new Shop();
            newShop.setDescription("Fresh Fruit Boxes");
            newShop.setBoxesCount(2);

            // Initialize a fruit list within each FruitBox
            fruitBoxes.forEach(fruitBox -> {
                fruitBox.setShop(newShop);
                Mutiny.fetch(fruitBox.getFruitList().size()); // Fetch the lazy-loaded fruitList
            });

            newShop.setFruitBoxes(fruitBoxes);

            return shopRepository.persist(newShop);
        });
    }
}