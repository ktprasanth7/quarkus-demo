package org.example.repository;

import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import jakarta.enterprise.context.ApplicationScoped;
import org.example.data.Fruit;

@ApplicationScoped
public class FruitRepository implements PanacheRepositoryBase<Fruit, Long> {

    /*

    Underlying Framework: Panache Reactive uses Hibernate Reactive under the hood for database interaction, which in turn integrates with Vert.x for reactive database access.
    Integration Points: When you configure a reactive datasource in Quarkus (e.g., quarkus.datasource.reactive.url=vertx-reactive:postgresql://localhost:5432/quarkus-demo), Vert.x manages the reactive connections, while Panache Reactive simplifies the data access layer with its reactive capabilities.
    Usage in Applications: Developers can use Panache Reactive entities and repositories (extends PanacheEntity, extends PanacheRepository) to perform database operations asynchronously, leveraging Vert.x's capabilities for efficient handling of requests and responses.

    */
}