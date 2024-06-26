package org.example.repository;

import io.quarkus.hibernate.reactive.panache.PanacheRepositoryBase;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import org.example.data.Fruit;

@ApplicationScoped
public class FruitRepository implements PanacheRepositoryBase<Fruit, Long> {

    /*
    Underlying Framework: Panache Reactive uses Hibernate Reactive under the hood for database interaction, which in turn integrates with Vert.x for reactive database access.
    Integration Points: When you configure a reactive datasource in Quarkus (e.g., quarkus.datasource.reactive.url=vertx-reactive:postgresql://localhost:5432/quarkus-demo), Vert.x manages the reactive connections, while Panache Reactive simplifies the data access layer with its reactive capabilities.
    Usage in Applications: Developers can use Panache Reactive entities and repositories (extends PanacheEntity, extends PanacheRepository) to perform database operations asynchronously, leveraging Vert.x's capabilities for efficient handling of requests and responses.
    */

    // Automatic query derivation from method names out-of-the-box like Spring Data JPA -> Possible in Quarkus but not in quarkus reactive
    // We can use custom queries to define with these method names and leverage the advantages like spring data jpa

    // Custom Queries
    // Simplifies querying by allowing you to write JPQL-like queries directly within the method.
    // Don't need to write explicit @Query annotations or complex native SQL queries for simple operations.

    // find Method: Very simple and concise for common queries.
    // @Query: More verbose, especially for simple queries. -> Verify
    // Native Queries: Most verbose and complex, suitable for specific use cases.

    public Uni<Fruit> findByIdAndName(Long id, String name) {
        return find("id = ?1 and name = ?2", id, name)
                .firstResult()
                .onItem().ifNull().failWith(() -> new RuntimeException("Fruit not found with id " + id + " and name " + name));
    }
}