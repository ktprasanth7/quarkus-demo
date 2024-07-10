package org.example.data;

import io.quarkus.hibernate.reactive.panache.PanacheEntityBase;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

@EqualsAndHashCode(callSuper = true)
@Entity
@Data
@Table(name = "shop", schema = "shop_schema")
public class Shop extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @OneToMany(mappedBy = "shop", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    public List<FruitBox> fruitBoxes;

    // 1 -> Orange, Apple

    @Column(length = 40, unique = true)
    public String description;

    @Column
    public Integer boxesCount;

    // Initializing fruitList at the time of accessing this object
    public List<FruitBox> getFruitBoxes() {
        if (this.fruitBoxes == null) {
            this.fruitBoxes = new ArrayList<>();
        }
        return this.fruitBoxes;
    }

}