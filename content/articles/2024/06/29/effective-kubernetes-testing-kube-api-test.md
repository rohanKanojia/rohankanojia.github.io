---
title: "Effective Kubernetes Testing in Java with Fabric8 Kube API Test"
draft: false
tags:
- kubernetes
- java
- envtest
- testing
date: 2024-06-29
lastmod: 2024-06-29
---

## Introduction:
Writing tests is extermely important in any kind of application, whether it's a normal application or a Kubernetes application. But how do you test your code that's written to interact with Kubernetes API Server? [Fabric8 Kubernetes Client](https://github.com/fabric8io/kubernetes-client) offers [Fabric8 Kubernetes Mock Server](https://central.sonatype.com/artifact/io.fabric8/kubernetes-server-mock) that creates a mock server instance which can mimic a Kubernetes API Server which is quite handy for testing simple scenarios. I have written these blog posts about it in case you're interested:
- [Mock Kubernetes API server in Java using Fabric8 Kubernetes Mock Server](https://itnext.io/mock-kubernetes-api-server-in-java-using-fabric8-kubernetes-mock-server-81a75cf6c47c)
- [How to write tests with Fabric8 Kubernetes Client](https://developers.redhat.com/articles/2023/01/24/how-write-tests-fabric8-kubernetes-client)

While [Fabric8 Kubernetes Mock Server](https://central.sonatype.com/artifact/io.fabric8/kubernetes-server-mock) works for simple to slightly complex scenarios, users usually start failing issues as it is not the same as a real Kubernetes API Server. When you start using advanced features of Kubernetes with [Fabric8 Kubernetes Mock Server](https://central.sonatype.com/artifact/io.fabric8/kubernetes-server-mock) , you will start facing issues as it would not return the same respone as expected from a real Kubernetes API Server.

Last year [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) was contributed to Fabric8 Kubernetes Client project by [Attila Mészáros](https://github.com/csviri). We are going to talk about this module in this blogpost and see how it improves testing support for Kubernetes Java applications by creating a ephemeral test instance of Kubernetes API Server for testing.

## History of the Project
[Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) was initially created as a PoC by [Attila Mészáros](https://github.com/csviri). It was inspired by GoLang [Controller RunTime Library envtest](https://pkg.go.dev/sigs.k8s.io/controller-runtime/pkg/envtest). It was initially called [jenvtest](https://github.com/java-operator-sdk/jenvtest) but while migrating to [Fabric8 Kubernetes Client](https://github.com/fabric8io/kubernetes-client), it was renamed to `Kube API Test`.


## Prerequisites:

You would need the following things to be able to follow this article:

*   Familiarity with [Kubernetes Java Client](https://github.com/fabric8io/kubernetes-client).
*   A [Java Development Kit](https://adoptopenjdk.net/) (JDK).
*   A text editor.

## Setting up Application:

You can either use an existing project or create a new one. I would be using my existing [Kubernetes Client Demo](https://github.com/rohanKanojia/kubernetes-client-demo) repository for writing test using Fabric8 Kube API Test.

Open the `pom.xml` and add [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) in `<dependency>` section:
```xml
<dependency>
    <groupId>io.fabric8</groupId>
    <artifactId>kube-api-test</artifactId>
    <version>${fabric8.version}</version>
    <scope>test</scope>
</dependency>
```
Now we should be able to use [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) in our project.


## Using Fabric8 Kube API Test in your project
Using [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) is just about adding this annotation in your test class:

```java
@EnableKubeAPIServer // Enable Kube Api Test Module in the test
class PodGroupServiceTest {
  // ...
}
```

This is going to download and run Kubernetes API server binaries directly in the background. It would download the binaries in `~/.kubeapitest` directory.

In order to interact with Kubernetes API server binaries running in the background, we would need to create KubernetesClient instance. [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) provides `@KubeConfig` annotation to inject kube config yaml to initialize any type of client. We are going to use Fabric8 Kubernetes Client in this blogpost. Here is sample code of initializing `KubernetesClient` that would interact with this test api server.

```java
@EnableKubeAPIServer
class PodGroupServiceTest {
  KubernetesClient kubernetesClient;

  @KubeConfig
  static String configYaml;

  @BeforeEach
  void setUp() {
    kubernetesClient = new KubernetesClientBuilder()
      .withConfig(Config.fromKubeconfig(configYaml))
      .build();
  }

  // ...
}
```

Now let's write a test for some class using [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md). We will be using existing test class [PodGroupService](https://github.com/rohanKanojia/kubernetes-client-demo/blob/master/writing-tests-with-fabric8/src/main/java/io/fabric8/demos/tests/mockserver/PodGroupService.java) that we used in [How to write tests using Fabric8](https://developers.redhat.com/articles/2023/01/24/how-write-tests-fabric8-kubernetes-client) blog post. It's a very simple class that groups a list of pods by a set of labels and performs operations on that group.

Let's say we want to write test for [PodGroupService's `addToGroup`](https://github.com/rohanKanojia/kubernetes-client-demo/blob/master/writing-tests-with-fabric8/src/main/java/io/fabric8/demos/tests/mockserver/PodGroupService.java#L31-L39) method. Here is how we will do it using [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) :

```java
@EnableKubeAPIServer(kubeAPIVersion = "1.30.0")
class PodGroupServiceTest {
  KubernetesClient kubernetesClient;

  @KubeConfig
  static String configYaml;

  @BeforeEach
  void setUp() {
    kubernetesClient = new KubernetesClientBuilder()
      .withConfig(Config.fromKubeconfig(configYaml))
      .build();
  }

  @Test
  void addToGroup_whenPodProvided_thenShouldUpdatePod() {
    // Given
    Map<String, String> matchLabel = Collections.singletonMap("app", "add-to-group");
    PodGroupService podGroupService = new PodGroupService(kubernetesClient, matchLabel);
    Pod p1 = createNewPod("p1", "add-to-group");

    // When
    podGroupService.addToGroup(p1);

    // Then
    PodList podList = podGroupService.list();
    assertTrue(podList.getItems().stream().map(Pod::getMetadata).map(ObjectMeta::getName).anyMatch(n -> n.startsWith("p1")));
  }

  private Pod createNewPod(String generateName, String appLabelValue) {
    return new PodBuilder()
      .withNewMetadata().withGenerateName(generateName).withLabels(Collections.singletonMap("app", appLabelValue)).endMetadata()
      .withNewSpec()
      .addNewContainer()
      .withName("demo-container")
      .withImage("alpine:latest")
      .endContainer()
      .endSpec()
      .build();
  }
}
```

You can see that experience of using [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) is as transparent as using a real Kubernetes cluster. There is no need to add any kind of expectations as we did in case of [Fabric8 Kubernetes Mock Server](https://itnext.io/mock-kubernetes-api-server-in-java-using-fabric8-kubernetes-mock-server-81a75cf6c47c).

Similarly, you can also write tests for more involved use cases like watch. Here is an example (I've omitted other details as they're same in all examples):

```java
  @Test
  void watch_whenInvoked_shouldMonitorUpdates() throws Exception {
    // Given
    PodGroupService podGroupService = new PodGroupService(kubernetesClient, Collections.singletonMap("app", "watch-test"));
    CountDownLatch eventReceivedLatch = new CountDownLatch(1);

    // When
    try (Watch ignore = podGroupService.watch(new Watcher<>() {
      @Override
      public void eventReceived(Action action, Pod pod) {
        eventReceivedLatch.countDown();
      }

      @Override
      public void onClose(WatcherException e) { }
    })) {
      podGroupService.addToGroup(createNewPod("p1-watch", "watch-test"));
      assertTrue(eventReceivedLatch.await(5, TimeUnit.SECONDS));
    }
    // Then
    assertEquals(0, eventReceivedLatch.getCount());
  }
```

Once initialized properly, writing tests using [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) as just like writing tests against a real Kubernetes Api server.

## Fabric8 Kube API Test Configuration Options:

[Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) provides these configuration options that can be provided to `@EnableKubeAPIServer` annotation. Here is an example of `@EnableKubeAPIServer` configured with available configuration options:

```java
@EnableKubeAPIServer(
  // Kubernetes Api Server version
  kubeAPIVersion = "1.30.0",
  // Kubernetes Api Server Flags
  apiServerFlags =  {"--audit-webhook-truncate-enabled"},
  // Whether modify local kube config
  updateKubeConfigFile = false
)
```
## Conclusion:

In this blog post, you learned how you can leverage on [Fabric8 Kube API Test](https://github.com/fabric8io/kubernetes-client/blob/main/doc/kube-api-test.md) to write robust tests that can ensure that your application is behaving as expected.

You can find code related to this blog post in [this GitHub Repository](https://github.com/rohanKanojia/kubernetes-client-demo).

To learn more about Fabric8 Kubernetes Client, check these links:

- [Fabric8 Kubernetes Client Documentation](https://github.com/fabric8io/kubernetes-client/tree/main/doc)
- [GitHub issue tracker](https://github.com/fabric8io/kubernetes-client/issues)
