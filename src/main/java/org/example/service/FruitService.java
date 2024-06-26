package org.example.service;

import io.quarkus.hibernate.reactive.panache.Panache;
import io.quarkus.hibernate.reactive.panache.common.WithTransaction;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.example.data.Fruit;
import org.example.repository.FruitRepository;

import java.util.List;

@ApplicationScoped
public class FruitService {

    @Inject
    FruitRepository fruitRepository;

    @WithTransaction
    public Uni<List<Fruit>> listAll() {
        return fruitRepository.listAll();
    }

    @WithTransaction
    public Uni<Fruit> getFruit(Long id) {
        return fruitRepository.findById(id);
    }

    @WithTransaction
    public Uni<Fruit> addFruit(Fruit fruit) {
//        return fruitRepository.persist(fruit).replaceWith(fruit);
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

    /*
    // With Transaction Usage
    @WithTransaction
    public Uni<Void> performReactiveTransactionalOperation() {
        return Uni.createFrom().item(() -> new MyEntity("data"))
                .onItem().transformToUni(entity -> {
                    // Persist the entity within the transaction context
                    return entity.persist();
                })
                .onItem().transformToUni(entity -> {
                    // Perform another database operation within the same transaction context
                    return AnotherEntity.update("some-query");
                });
    }
    */
}
