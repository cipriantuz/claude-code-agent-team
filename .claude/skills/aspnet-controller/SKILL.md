---
name: aspnet-controller
disable-model-invocation: true
description: Trigger when user says "add endpoint", "create controller", "expose API", "CRUD endpoint", "minimal API" — scaffold a single ASP.NET Core minimal API feature slice. NOT when the user asks for a full feature lifecycle (architecture + implementation + tests orchestrated) — use `aspnet-feature-bundle` for that.
---

# ASP.NET Core Endpoint Scaffold

## Before writing any code, ask the owner

1. **Resource name** (e.g., `Order`, `Product`, `Invoice`)
2. **Fields** (name + type, e.g., `Title: string, Price: decimal, IsActive: bool`)
3. **Project path** (absolute, e.g., `src/MyApi/`)
4. **Operations needed** (GET all, GET by id, POST, PUT, DELETE — or CRUD for all five)
5. **Existing DbContext name?** (check `grep -r DbContext` if not provided)

## Design rules

- **Minimal API only** — no `[ApiController]` classes unless project already uses them
- All handlers are `async` returning `Task<IResult>`
- Return `Results.Ok()`, `Results.NotFound()`, `Results.BadRequest()`, `Results.Created()`
- DTOs are `record` types with data annotations; add FluentValidation only if project already references it
- No business logic in endpoints — delegate to service

## File structure to produce

```
{ProjectRoot}/
  Endpoints/{Resource}Endpoints.cs      ← extension method MapXxxEndpoints
  Models/Dtos/{Resource}Dto.cs          ← request/response records
  Services/{Resource}Service.cs         ← implementation
  Services/I{Resource}Service.cs        ← interface
{ProjectRoot}.Tests/
  Endpoints/{Resource}EndpointsTests.cs ← xUnit + WebApplicationFactory
```

Register in `Program.cs`:
```csharp
builder.Services.AddScoped<I{Resource}Service, {Resource}Service>();
app.Map{Resource}Endpoints();
```

## Code templates

**Endpoints/{Resource}Endpoints.cs**
```csharp
public static class {Resource}Endpoints
{
    public static IEndpointRouteBuilder Map{Resource}Endpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/{resources}").WithTags("{Resources}");

        group.MapGet("/", GetAll{Resources});
        group.MapGet("/{id:int}", Get{Resource}ById);
        group.MapPost("/", Create{Resource});
        group.MapPut("/{id:int}", Update{Resource});
        group.MapDelete("/{id:int}", Delete{Resource});

        return app;
    }

    private static async Task<IResult> GetAll{Resources}(I{Resource}Service svc)
        => Results.Ok(await svc.GetAllAsync());

    private static async Task<IResult> Get{Resource}ById(int id, I{Resource}Service svc)
        => await svc.GetByIdAsync(id) is { } item ? Results.Ok(item) : Results.NotFound();

    private static async Task<IResult> Create{Resource}([FromBody] Create{Resource}Dto dto, I{Resource}Service svc)
        => Results.Created($"/api/{resources}/{(await svc.CreateAsync(dto)).Id}", null);

    private static async Task<IResult> Update{Resource}(int id, [FromBody] Update{Resource}Dto dto, I{Resource}Service svc)
        => await svc.UpdateAsync(id, dto) ? Results.NoContent() : Results.NotFound();

    private static async Task<IResult> Delete{Resource}(int id, I{Resource}Service svc)
        => await svc.DeleteAsync(id) ? Results.NoContent() : Results.NotFound();
}
```

**Models/Dtos/{Resource}Dto.cs**
```csharp
public record {Resource}Dto(int Id, {properties});
public record Create{Resource}Dto([Required] {required_properties});
public record Update{Resource}Dto({properties});
```

## After scaffolding

- Run `dotnet build` — fix any compile errors before reporting done
- Run `dotnet test` — report pass/fail count
