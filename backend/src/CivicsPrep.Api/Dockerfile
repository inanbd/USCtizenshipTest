# Build and run the Civics Prep API.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first so the layer caches while only source changes.
COPY Directory.Build.props ./
COPY src/CivicsPrep.Domain/*.csproj          src/CivicsPrep.Domain/
COPY src/CivicsPrep.Application/*.csproj     src/CivicsPrep.Application/
COPY src/CivicsPrep.Infrastructure/*.csproj  src/CivicsPrep.Infrastructure/
COPY src/CivicsPrep.Contracts/*.csproj       src/CivicsPrep.Contracts/
COPY src/CivicsPrep.Api/*.csproj             src/CivicsPrep.Api/
RUN dotnet restore src/CivicsPrep.Api/CivicsPrep.Api.csproj

COPY src/ src/
RUN dotnet publish src/CivicsPrep.Api/CivicsPrep.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app ./

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "CivicsPrep.Api.dll"]
