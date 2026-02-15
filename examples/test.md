# Test Markdown with Mermaid

This is a test file to verify the memd.nvim plugin works correctly.

## Simple Flowchart

```mermaid
flowchart LR
    A[Start] --> B{Decision}
    B -->|Yes| C[Action]
    B -->|No| D[End]
    C --> D
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant Client
    participant Server
    participant Database

    Client->>Server: Request data
    Server->>Database: Query
    Database-->>Server: Result
    Server-->>Client: Response
```

## Class Diagram

```mermaid
classDiagram
    Animal <|-- Dog
    Animal <|-- Cat

    class Animal {
        +name: String
        +eat()
        +sleep()
    }

    class Dog {
        +bark()
    }

    class Cat {
        +meow()
    }
```

## Regular Text

This is just regular markdown text. It should render normally without any special processing.

- Point 1
- Point 2
- Point 3

**Bold** and *italic* text should work fine.

`Inline code` is also supported.
