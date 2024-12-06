---
title: "Simplify Kubernetes Operator Development using Java Operator SDK"
draft: false
tags:
- kubernetes
- java
- operators
- testing
date: 2024-12-06
lastmod: 2024-12-06
---

## Introduction:

Kubernetes is designed for automation. We can develop [Kubernetes Operators](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) to 
encapsulate the operational knowledge for running specific applications and automate routine tasks. Operators monitor Kubernetes cluster
state and make changes to maintain desired configuration, acting as a specialized controller. Operators are Kubernetes controllers that extend
the cluster's behavior by managing custom resources and performing domain-specific actions.

You could develop the Kubernetes Operators in any library using a Kubernetes API Client. For Java, it would be using [Fabric8 Kubernetes Client](https://github.com/fabric8io/kubernetes-client).
I have written some blogposts in past for doing this:
- [Write a simple Kubernetes Operator in Java using the Fabric8 Kubernetes Client](https://developers.redhat.com/blog/2019/10/07/write-a-simple-kubernetes-operator-in-java-using-the-fabric8-kubernetes-client)
- [Writing Kubernetes Sample Controller in Java](https://itnext.io/writing-kubernetes-sample-controller-in-java-c8edc38f348f)

However, I recently tried out the [Java Operator SDK](https://github.com/operator-framework/java-operator-sdk) for developing a Kubernetes Operator and realized
how easy and smooth the development process was as compared to doing everything on your own using a Kubernetes Client.

The [Java Operator SDK](https://github.com/operator-framework/java-operator-sdk) is a library that simplifies the process of building Kubernetes operators using Java.
With the Java Operator SDK, developers can leverage the power of Kubernetes in a familiar Java ecosystem, enabling seamless integration and management of custom applications 
and infrastructure.


## History of the Project
[Java Operator SDK](https://github.com/operator-framework/java-operator-sdk) was initially developed by a European startup named [Container Solutions](https://www.container-solutions.com/). It was
designed to be a high-level framework for implementing operators in Java, equivalent to [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime) GoLang library. It got recognized by
[Red Hat](https://www.redhat.com/en) later and received contributions.

In 2023, this project became a part of [CNCF](https://www.cncf.io/) as an incubating project as part of Operator Framework (see [CNCF announcement](https://www.cncf.io/blog/2023/04/18/java-operator-sdk-is-joining-operator-framework/)).

## Prerequisites:

You would need the following things to be able to follow this article:

*   Familiarity with [Kubernetes Java Client](https://github.com/fabric8io/kubernetes-client).
*   A [Java Development Kit](https://adoptopenjdk.net/) (JDK).
*   A text editor.
*   [Minikube](https://minikube.sigs.k8s.io/docs/) cluster

## Setting up Application:
In order to use Java Operator SDK, you need to include this dependency in your project:

```xml
<dependency>
    <groupId>io.javaoperatorsdk</groupId>
    <artifactId>operator-framework</artifactId>
</dependency>
```

If you're using [Quarkus](https://quarkus.io/), you can use this Quarkus Extension:
```xml
<dependency>
    <groupId>io.quarkiverse.operatorsdk</groupId>
    <artifactId>quarkus-operator-sdk</artifactId>
</dependency>
```

If you're using [Spring Boot](https://spring.io/projects/spring-boot), you can use this Spring Boot Extension:
```xml
<dependency>
    <groupId>io.javaoperatorsdk</groupId>
    <artifactId>operator-framework-spring-boot-starter</artifactId>
    <version>${java-operator-sdk.version}</version>
</dependency>
```

## Using Java Operator SDK in your project
In order to use Java Operator SDK in your application, you need to define a class in your application that would be responsible for
reacting to all the events for your custom resource. 

Let's try to understand how to use it with the help of an example. 

We will try to port [Kubernetes Sample Controller](https://github.com/kubernetes/sample-controller) using [Java Operator SDK](https://github.com/operator-framework/java-operator-sdk).

It manages a simple Kubernetes Custom Resource named `Foo` that manages a Deployment resource. You define a `Foo` resource where
you specify Deployment name and the number of replicas you want.

Here is a diagram to give you better idea of how it would work:

![Sample Operator Kubernetes](/images/KubernetesSampleOperatorFinal.png)

### Custom Resource Definition for Foo resource
In order to create a new [Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/), we need to create a [Custom Resource Definition](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) in Kubernetes.

You can see YAML for creating Foo CustomResourceDefinition in GitHub repository [here](https://github.com/rohankanojia-demos/sample-operator-java-operator-sdk/blob/main/src/main/resources/crd/foo-crd.yaml).

### Generating Java types for Foo Custom Resource

In order to use this Kubernetes Custom resource programmatically, you would need to generate java model types. I've used Java Generator Maven Plugin to do this:

Here is the plugin configuration:
```xml
<plugin>
    <groupId>io.fabric8</groupId>
    <artifactId>java-generator-maven-plugin</artifactId>
    <version>${fabric8.version}</version>
    <configuration>
        <source>${project.basedir}/src/main/resources/crd/foo-crd.yaml</source>
    </configuration>
    <executions>
        <execution>
            <goals>
                <goal>generate</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```
This configuration would read CustomResourceDefinition yaml file in `src/main/resources` directory and generate java classes in `target/generated-sources`.

### Writing the main code for application

Usually in a Kubernetes Operator you need to define logic to handle all the events related to custom resource in order to 
maintain the desired state. This is done in a `Reconciler`.

We will implement this in a class using already provided `io.javaoperatorsdk.operator.api.reconciler.Reconciler` interface and `@io.javaoperatorsdk.operator.api.reconciler.ControllerConfigurationControllerConfiguration` annotation:

```java
@ControllerConfiguration(
  dependents = {
    @Dependent(type = DeploymentDependentResource.class)
  })
public class FooReconciler implements Reconciler<Foo> {
  private static final Logger logger = LoggerFactory.getLogger(FooReconciler.class.getName());

  @Override
  public UpdateControl<Foo> reconcile(final Foo foo, Context<Foo> context) throws Exception {
    return context.getSecondaryResource(Deployment.class).map(deployment -> {
      Foo updatedFoo = updateAvailableReplicasInFooStatus(foo, deployment.getSpec().getReplicas());
      logger.info("Updating status of Foo {} in namespace {} to {} ready replicas",
        foo.getMetadata().getName(),
        foo.getMetadata().getNamespace(),
        foo.getSpec().getReplicas());
      return UpdateControl.patchStatus(updatedFoo);
    }).orElseGet(UpdateControl::noUpdate);
  }

  private Foo updateAvailableReplicasInFooStatus(Foo foo, long replicas) {
    FooStatus fooStatus = new FooStatus();
    fooStatus.setAvailableReplicas(replicas);
    // NEVER modify objects from the store. It's a read-only, local cache.
    // You can create a copy manually and modify it
    Foo fooClone = Serialization.clone(foo);
    fooClone.setStatus(fooStatus);
    return fooClone;
  }
}
```

- `@ControllerConfiguration` annotation registers the class as controller for the operator. It also allows providing additional parameters like dependent resources, namespace, etc.
  - Since this `Foo` resource is going to manage a `Deployment`, we have used a `dependents` configuration option. In this option, we provide a class that would be handling dependents.
- We have used the `Reconciler` interface from Java Operator SDK and overridden `reconcile` method. Here is where we define our logic for matching desired state of the resource by updating `Foo` status.

Here is code for handling dependent Deployment resource, it's the class referenced in `dependents` of `@ControllerConfiguration`:
```java
@KubernetesDependent(labelSelector = "app.kubernetes.io/managed-by=sample-operator")
public class DeploymentDependentResource extends CRUDKubernetesDependentResource<Deployment, Foo> {
  public DeploymentDependentResource() {
    super(Deployment.class);
  }

  @Override
  protected Deployment desired(Foo foo, Context<Foo> context) {
    final ObjectMeta fooMetadata = foo.getMetadata();
    final String fooName = fooMetadata.getName();
    return new DeploymentBuilder()
      .withNewMetadata()
      .withName(fooName)
      .withNamespace(fooMetadata.getNamespace())
      .addToLabels("app", fooName)
      .addToLabels("app.kubernetes.io/part-of", fooName)
      .addToLabels("app.kubernetes.io/managed-by", "tomcat-operator")
      .endMetadata()
      .withNewSpec()
      .withNewSelector().addToMatchLabels("app", fooName).endSelector()
      .withReplicas(foo.getSpec().getReplicas().intValue())
      .withNewTemplate()
      .withNewMetadata().addToLabels("app", fooName).endMetadata()
      .withNewSpec()
      .addNewContainer()
      .withName("nginx")
      .withImage("nginx:latest").endContainer()
      .endSpec()
      .endTemplate()
      .endSpec()
      .build();
  }
}
```

In above class, we define desired Deployment state as per the `Foo` custom resource. It creates a simple Deployment object with the provided 
number of replicas and name with opinionated `nginx:latest` image.

## Deploying the Operator

Now that we've written code for handling events and dependent resources, let's go ahead and deploy it.

We will be using [Eclipse JKube](https://github.com/eclipse/jkube) [Kubernetes Maven Plugin](https://eclipse.dev/jkube/docs/kubernetes-maven-plugin/) to deploy this operator to Kubernetes Cluster.

1. Install Custom Resource Definition first:
```shell
kubectl create -f src/main/resources/crd/foo-crd.yaml
```
2. Install ClusterRole, ClusterRoleBinding and ServiceAccount for Operator to work with
```shell
kubectl create -f src/main/resources/foo-serviceaccount-and-role-binding.yml
```
3. Deploy Operator to Kubernetes cluster using [Kubernetes Maven Plugin](https://eclipse.dev/jkube/docs/kubernetes-maven-plugin/)
```shell
# (Optional) To point your shell to minikube's docker-daemon, run:
eval $(minikube -p minikube docker-env)
mvn package k8s:build k8s:resource k8s:apply
```

## Testing the Operator
In order to test whether our operator is working as expected, we need to create some sample `Foo` custom resource YAML files 
and see if corresponding Deployment is getting created for each `Foo` resource.

Create an instance of `Foo` resource:
```shell
kubectl create -f src/main/resources/example-foo.yaml
foo.samplecontroller.k8s.io/example-foo created
```
You'd notice that Operator detected this change and created the dependent resource Deployment for this `example-foo` resource.

Here is a short gif of demo using [Podman Desktop](https://podman-desktop.io/):

![Sample Operator Kubernetes Demo](/images/sample-operator-josdk-in-action.gif)


## Conclusion:  

The Java Operator SDK streamlines the development of Kubernetes operators, enabling Java developers to harness the full potential of Kubernetes while leveraging their existing Java skills. 
Whether you're managing complex applications or automating infrastructure tasks, the Java Operator SDK provides a powerful toolkit to extend Kubernetes with custom logic and automation.

You can find code used this blog post in this [GitHub repository](https://github.com/rohankanojia-demos/sample-operator-java-operator-sdk).

## References

- [Red Hat Developer : Write Kubernetes Operators with Java Operator SDK](https://developers.redhat.com/articles/2022/02/15/write-kubernetes-java-java-operator-sdk)
- [Java Operator SDK Documentation](https://javaoperatorsdk.io/docs/getting-started/)
- [Java Operator SDK Best Practices](https://javaoperatorsdk.io/docs/patterns-and-best-practices/)
- [Sample projects](https://javaoperatorsdk.io/docs/using-samples/)