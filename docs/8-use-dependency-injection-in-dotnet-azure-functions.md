# Workshop: Use dependency injection in .NET Azure Functions

- [Introduction](#introduction)
- [Learning Objectives](#learning-objectives)
- [Challenges](#challenges)
    - [Challenge 1: Update a function app to use dependency injection](#challenge-1)
- [Additional Resources](#additional-resources)

## Introduction <a name="introduction"></a>
Azure Functions supports the dependency injection (DI) software design pattern, which is a technique to achieve [Inversion of Control (IoC)](https://learn.microsoft.com/en-us/dotnet/standard/modern-web-apps-azure-architecture/architectural-principles#dependency-inversion) between classes and their dependencies, which means that the classes do not create or manage their dependencies, but receive them from an external source. This way, you can separate the concerns of your functions from the concerns of their dependencies, such as configuration, logging, data access, or business logic. You can also replace or mock your dependencies easily when testing or debugging your functions

Using dependency injection can help you write cleaner, more modular, and more testable code.
For more information of how to leverage dependency injection to configure services lifetime, use options and settings for configurations in Azure Functions, see [Dependency injection in Azure Functions](https://docs.microsoft.com/en-us/azure/azure-functions/functions-dotnet-dependency-injection).

## Learning Objectives <a name="learning-objectives"></a>
1. Use dependency injection in .NET Azure Functions to separate the concerns of your functions from the concerns of their dependencies, such as configuration, logging, data access, or business logic.

## Challenges <a name="challenges"></a>
1. Update a function app to use dependency injection.
1. Use injected ILogger<T> in your functions.

### Challenge 1: Update a function app to use dependency injection <a name="challenge-1"></a>

1. Before you can use dependency injection in your backend functionapp, you must install the following NuGet packages:
    ```bash
    pushd src/backend
    dotnet add package Microsoft.Extensions.DependencyInjection --version 7.0.0
    dotnet add package Microsoft.Azure.Functions.Extensions --version 1.1.0
    popd
    ```

1. Create new file **Startup.cs** where you will register your services. To register services, create a method to configure and add the **Healthz** component to an IFunctionsHostBuilder instance. The Azure Functions host creates an instance of IFunctionsHostBuilder and passes it directly into your method.

    ```csharp
    using Microsoft.Azure.Functions.Extensions.DependencyInjection;
    using Microsoft.Extensions.DependencyInjection;

    [assembly: FunctionsStartup(typeof(backend.Startup))]
    namespace backend
    {
        public class Startup : FunctionsStartup
        {
            public override void Configure(IFunctionsHostBuilder builder)
            {

                builder.Services.AddSingleton<Healthz>();
            }
        }
    }
    ```
1. Update **Healthz.cs** function to be non-static.
1. Run locally your backend application and validate is working as expected.


### Challenge 2: Use injected ILogger<T> in your functions <a name="challenge-2"></a>
The host injects ILogger<T> and ILoggerFactory services into constructors. However, by default these new logging filters are filtered out of the function logs. You need to modify the host.json file to opt-in to additional filters and categories.

1. Add a constructor that accepts <ILogger<Healthz>> log as a parameter to **Healthz.cs**. The Azure Functions host creates an instance of ILogger<T> and passes it directly into your constructor.

    ```csharp
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Azure.WebJobs.Extensions.Http;
    using Microsoft.AspNetCore.Http;
    using Microsoft.Extensions.Logging;

    namespace backend
    {
        public class Healthz
        {
            private readonly ILogger<Healthz> _log;

            public Healthz(ILogger<Healthz> log)
            {
                _log = log;
            }

            ...
    ```
1. Opt-in new additional filter in **hosts.json** by provising Healthz class namespace and name:

    ```json
    "logLevel": {
        // "default": "Information"
        "backend.Healthz": "Information"
    }
    ```
1. Run locally your backend application and validate logs are written to console while Healthz endpoint is called.

# Additional resource
| Name | Description |
| --- | --- |
| Use dependency injection in .NET Azure Functions  | https://learn.microsoft.com/en-us/azure/azure-functions/functions-dotnet-dependency-injection |
