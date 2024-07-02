package org.example.request;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import org.example.data.Fruit;

@Getter
@Setter
@AllArgsConstructor
public class AddFruitToBoxRequest {
    private Fruit fruit;
    private Long boxId;
    private Integer quantity;
}