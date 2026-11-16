# Global Codex Instructions

## Working style

- Lead with the outcome and keep explanations concise.
- Make reasonable, low-risk assumptions and continue instead of stopping for unnecessary clarification.
- Explain important assumptions, tradeoffs, blockers, and verification results.
- Preserve existing user changes and avoid modifying unrelated files.
- When the user provides a work directory, keep all task files in that directory or its subdirectories, including sources, downloads, intermediate files, scripts, reports, and final deliverables. Use it as the working directory and avoid duplicate copies elsewhere unless the user explicitly requests another location.

## Implementation

- Always organize imports in modified source files before completing a change.
- Do not use `var` anywhere in code; always use strongly typed class names.
- Always use four spaces for indentation in YAML files.
- Always use the Sora font in generated PDF documents.
- Inspect the existing project structure and conventions before changing code.
- Keep implementations simple, maintainable, and consistent with the surrounding codebase.
- Do not introduce new production dependencies unless they are necessary.
- Never commit, push, create a pull request, or deploy unless explicitly requested.
- Maintain durable reference documentation in a `documentation` folder within each project, and keep that folder indexed for quick lookup.
- Preserve reusable generators, scripts, templates, fixtures, and automation helpers when they can reduce future execution time, repeated work, or token usage. Move them from temporary locations into an appropriate durable project folder such as `tools/`, `scripts/`, or `documentation/templates/`, and document their purpose and usage. Remove only disposable outputs, caches, and one-off intermediates that have no realistic reuse value.
- When documenting enums, keep the enum codes as the actual values and retain
  their human-readable meanings using documentation metadata, such as XSD
  `xs:annotation` and `xs:documentation`.
- Use constructor injection for required dependencies; do not use field injection.
- Avoid circular dependencies and oversized classes. Split classes when responsibilities become unrelated.

## Architecture and API design

- Keep controllers thin: handle HTTP concerns only and delegate business logic to services.
- Keep repositories limited to persistence operations.
- Place transaction boundaries in services.
- Use matching class suffixes such as `*Controller`, `*Service`, `*Repository`, `*Entity`, `*Configuration`, and `*Exception`.
- Put request and response models in a `dto` package; do not expose persistence entities directly through APIs.
- Validate request DTOs with Jakarta Validation and `@Valid`.
- Put DTO and entity conversion in a `mapper` package; do not embed mapping logic in controllers.
- Handle API errors centrally with `@RestControllerAdvice` and RFC 9457 `ProblemDetail`.
- Never reveal stack traces or implementation details in API responses.
- Return appropriate HTTP status codes and use a consistent error-response structure.
- Keep public APIs backward compatible unless a breaking change is explicitly approved.
- Exclude fields with `null` values from JSON API responses. Configure this
  centrally through Jackson rather than annotating individual DTO fields,
  unless an API explicitly requires null-valued fields to be serialized.

## Persistence

- Perform database inspection and diagnostic access in an explicitly read-only
  transaction. Do not execute DDL or DML unless the user separately and
  explicitly authorizes that database change.
- Use database migrations for schema changes.
- Do not rely on automatic schema generation in production.
- Before creating or modifying an entity or persistence query, inspect the most
  recent authentic schema source. This may be read-only metadata from the
  configured database or the current authoritative local DDL. Inspect its
  schema, columns, keys, constraints, indexes, and generation metadata.
- Always create JPA/Hibernate mappings from the most recent authentic source.
  Database metadata and authoritative local DDL are both valid sources. Never
  infer mappings from sample data, legacy code, or API DTOs. Document the source
  used and mark live-schema verification as pending when the local DDL has not
  yet been applied to the database.
- Keep entity classes limited to columns required by the application unless the
  user explicitly requests a complete table projection.
- For every mapped field, include all applicable JPA/Hibernate mapping details:
  exact schema, table and column names; compatible Java and database types;
  length, precision, scale, nullability, uniqueness, fixed-width `CHAR`
  behavior, identifier and identity/generation strategy, and temporal, enum,
  binary, or large-object handling.
- Map verified primary keys, composite keys, unique constraints, foreign keys,
  relationships, and table indexes with standard JPA/Hibernate annotations when
  they are relevant and expressible. Never invent a relationship without a
  database constraint. Align query parameter types with the mapped column types.
- Prefer standard Jakarta Persistence annotations, dialect-neutral Java/JDBC
  types, and portable identity or sequence strategies that let Hibernate's
  active dialect adapt mappings across PostgreSQL, Microsoft SQL Server, and
  Oracle Database. Avoid database-specific `columnDefinition` or SQL fragments
  when a standard annotation or Hibernate type code can express the mapping;
  never weaken correctness against the verified live schema for portability.
- Never use JPQL or native SQL queries in a project that has JPA implemented.
  Use Spring Data derived methods, Specifications, Query by Example, or the JPA
  Criteria API instead. JPQL or native SQL queries are permitted only when the
  project does not implement JPA.
- Do not include the database schema name in entity or repository class names
  unless omitting it would create a naming conflict. When a conflict exists,
  use the schema name only on the conflicting classes to disambiguate them.
- Create focused, conventional JPA entity classes in the style generated by
  IntelliJ IDEA: one public `*Entity` class per file, a package matching the
  database schema, explicit `@Entity` and `@Table` mappings, explicit identifier
  and required-column mappings, correct composite-key handling, and no business
  logic.
- Use Lombok `@Getter`, `@Setter`, `@Builder`, `@NoArgsConstructor`, and
  `@AllArgsConstructor` on JPA entity classes.

## Verification

- Run relevant builds and tests after modifying code.
- For Maven projects, run `mvn clean verify` when practical.
- Report build or test failures accurately; do not claim success when verification did not complete.
- Distinguish source-code failures from environment, permissions, network, and tooling failures.
- Add tests for every new behavior and a regression test for every bug fix.
- Prefer focused test slices such as `@WebMvcTest` and `@DataJpaTest`; use full integration tests only when needed.

## Security, configuration, and observability

- Never log passwords, tokens, account numbers, personal data, full request
  bodies, or other sensitive information unless the user explicitly instructs
  you in the current task to log the specific data. Limit the exception to the
  named data and requested logging destination.
- Keep environment-specific values outside source control and provide safe defaults only for non-sensitive local settings.
- Expose only the Actuator `health` and `info` endpoints by default.
- Do not expose additional Actuator endpoints unless they are protected by authentication or an internal network.
- Document every new environment variable, endpoint, and operational dependency in the README.

## Java and Maven defaults

- Use the Java version configured by the project.
- Use `OffsetDateTime` for all date-time values and serialize them using
  `DateTimeFormatter.ISO_OFFSET_DATE_TIME`, for example:
  `2026-08-07T02:15:00.2258816+05:30`.
- Treat monetary and amount values as `BigDecimal` and serialize them as JSON
  numbers with exactly two decimal places.
- Serialize database `DATE` values as ISO dates and date-time values as ISO
  date-time values, without inventing an offset that the database did not store.
- Prefer the Maven wrapper when it works; otherwise use the installed Maven executable.
- On this Windows system, Maven may be installed at:
  `C:\Tools\apache-maven-3.9.16\bin\mvn.cmd`
- Do not assume CBS services depend on `cbs-parent` or `cbs-dao`; confirm the intended dependencies first.

## PostgreSQL tools

- On this Windows system, prefer the `psql` executable bundled with pgAdmin at:
  `C:\Program Files\pgAdmin 4\runtime\psql.exe`
- If that executable is unavailable, use another installed `psql` executable or
  the project's PostgreSQL JDBC driver.

## Maven and dependency management

- Separate adjacent Maven `<dependency>` elements with a blank line.
- Always use the latest stable Spring Boot 4.x release when creating a Spring Boot project.
- Use the latest compatible stable Spring Cloud release when Spring Cloud is required.
- Use current stable versions of other dependencies that are compatible with the project.
- Verify dependency versions and compatibility against authoritative documentation.
- Do not automatically upgrade dependencies in existing projects unless the user requests it.
- Exclude `target/` when archiving projects or uploading them to Google Drive.
- Before committing a project to Git or backing it up to Google Drive, copy the
  current global instructions to `documentation/Codex-Global-AGENTS.md` in the
  project. Include that tracked Markdown copy in both Git and the Drive backup.

## Global task list

- Keep cross-project and future work in `%USERPROFILE%\.codex\GLOBAL-TASKS.md`.
- Consult and update that file when the user asks to list, add, complete, or remove
  global tasks.

## Restoring on another PC

1. Download this file from Google Drive.
2. Create the Codex home directory if it does not exist:

   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex"
   ```

3. Copy and rename the downloaded file:

   ```powershell
   Copy-Item ".\Codex-Global-AGENTS.md" "$env:USERPROFILE\.codex\AGENTS.md"
   ```

4. Start a new Codex task so the global instructions are loaded.

Repository-level `AGENTS.md` files and more deeply nested instruction files can
add to or override these global defaults for their applicable directories.
