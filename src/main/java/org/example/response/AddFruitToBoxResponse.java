package org.example.response;

import lombok.Getter;
import lombok.Setter;
import org.example.data.Fruit;

import java.util.ArrayList;

@Getter
@Setter
public class AddFruitToBoxResponse {
    public Long id;
    public ArrayList<Fruit> fruitTypes;
    public String description;
    public Integer boxPrice;
    public Integer quantity; // Quantity combining all fruit types
    public String status;
}