package org.example.repository;

import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import jakarta.enterprise.context.ApplicationScoped;
import org.example.data.FruitBox;
import org.example.data.Shop;

@ApplicationScoped
public class ShopRepository implements PanacheRepositoryBase<Shop, Long> {

}