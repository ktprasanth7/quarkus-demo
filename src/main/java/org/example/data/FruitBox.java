package org.example.data;

import io.quarkus.hibernate.reactive.panache.PanacheEntityBase;
import io.smallrye.mutiny.Uni;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.reactive.mutiny.Mutiny;

import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@Table(name = "fruit_box")
public class FruitBox extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @OneToMany(mappedBy = "fruitBox", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    public List<Fruit> fruitList;

    // Example using a list of fruit IDs
//    @ElementCollection
//    @CollectionTable(name = "fruit_box_fruit_ids", joinColumns = @JoinColumn(name = "fruit_box_id"))
//    @Column(name = "fruit_id")
//    public ArrayList<Long> fruitIdList;

    // 1 -> Orange, Apple

    @Column(length = 40, unique = true)
    public String description;

    @Column
    public Integer boxPrice;

    @Column
    public Integer quantity;

    @ManyToOne
    @JoinColumn(name = "shop_id")
    public Shop shop;

    // Initializing fruitList at the time of accessing this object
    public List<Fruit> getFruitList() {
        if (this.fruitList == null) {
            this.fruitList = new ArrayList<>();
        }
        return this.fruitList;
    }

}