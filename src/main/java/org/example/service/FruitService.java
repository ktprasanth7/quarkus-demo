package org.example.service;

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

    public Uni<List<Fruit>> listAll() {
        return fruitRepository.listAll();
    }

    public Uni<Fruit> getFruit(Long id) {
        return fruitRepository.findById(id);
    }

    public Uni<Fruit> addFruit(Fruit fruit) {
//        return fruitRepository.persist(fruit).replaceWith(fruit);
        return fruitRepository.persist(fruit);
    }

    public Uni<Fruit> updateFruit(Long id, Fruit fruit) {
        return fruitRepository.findById(id)
                .onItem().ifNotNull().invoke(entity -> {
                    entity.name = fruit.name;
                    entity.color = fruit.color;
                    entity.price = fruit.price;
                });
    }

    public Uni<Boolean> deleteFruit(Long id) {
        return fruitRepository.deleteById(id);
    }
}
