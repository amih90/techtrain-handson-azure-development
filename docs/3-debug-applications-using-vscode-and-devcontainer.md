# Workshop: Debug applications using VSCode and devcontainer

- [Introduction](#introduction)
- [Learning Objectives](#learning-objectives)
- [Challenges](#challenges)
    - [Challenge 1: Debug an application inside a local devcontainer](#challenge-2)
- [Additional Resources](#additional-resources)

## Introduction <a name="introduction"></a>
Having a local development environment is important because it allows you to test your application in a controlled environment before deploying it to production. This way, you can catch and fix issues early on, without affecting your users. Additionally, local development allows you to experiment with new features and functionalities without worrying about breaking your production environment.

Being able to debug your application locally is also important because it allows you to quickly identify and fix issues early on, before they become bigger problems that could potentially ruin your project.

Now that you have a full-featured development environment based on devcontainer, you are able to run and debug your applications locally leveraging VSCode extensions capability and tools no matter which technology stack you are using. The ToDo app is based on React and .NET, but you can use the same approach to debug any application.

## Learning Objectives <a name="learning-objectives"></a>
1. Leveraging a dev container to debug your application.

## Challenges <a name="challenges"></a>
1. Debug an application inside a local devcontainer.

### Challenge 1: Debug an application inside a local devcontainer <a name="challenge-1"></a>
Debugging an application inside a devcontainer is a powerful feature of the Visual Studio Code Dev Containers extension. It allows you to debug your application in a containerized environment, which can be useful for testing and debugging your code in a consistent and isolated environment.

1. Configure Azure Credentials inside the devcontainer by signing into your Azure Account, using one of the following approaches:
    1. Using **Azure CLI** by running `az login` in terminal.
    1. Using the [Command Palette](https://code.visualstudio.com/docs/getstarted/userinterface#_command-palette) by running `Ctrl` + `Shift` + `P` and selecting **Azure: Sign In**.
    1. Using Azure VSCode extension shortcut on left menu.
        1. Press the **Azure** icon.
        1. Select **Sign In**.

    > **Azure Credentials** - are used to authenticate with Azure when resources are running locally. The following applications will try to connect to Azure Key Vault and Cosmos DB.

1. Debug **API** application.
    1. Generate a developer certificate by running `dotnet dev-certs https` in the terminal.
    1. Press `Ctrl`+ `Shift`+ `D` to open the **Debug** view.
    1. Select **Debug API**.
    1. Go to https://localhost:3101/index.html and review the available Swagger API.

1. Run **Web** application:
    1. Build and Run the React based web application via VSCode task, **Menu** -> **Terminal** -> **Run Task** -> **Start Web**, it might take few minutes.
    1. Go to https://localhost:3000.

## Additional Resources <a name="additional-resources"></a>
| Name | Description |
| --- | --- |
| [Visual Studio Code User Interface](https://code.visualstudio.com/docs/getstarted/userinterface) | VSCode user interface documentation |
