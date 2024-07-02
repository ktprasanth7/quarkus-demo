package org.example.data;

import io.quarkus.hibernate.reactive.panache.PanacheEntityBase;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Getter
@Setter
@Table(name = "fruit")
public class Fruit extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(length = 40, unique = true)
    public String name;

    @Column(length = 40, unique = true)
    public String color;

    @Column
    public Integer price;

    @Column
    public BigDecimal decimal;


    @ManyToOne
    @JoinColumn(name = "fruit_box_id")
    public FruitBox fruitBox;
}