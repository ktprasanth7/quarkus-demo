package org.example.repository;

import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import org.example.data.Fruit;
import org.example.data.FruitBox;

@ApplicationScoped
public class FruitBoxRepository implements PanacheRepositoryBase<FruitBox, Long> {

}