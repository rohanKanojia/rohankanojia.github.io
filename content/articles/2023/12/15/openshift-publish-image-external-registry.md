---
title: "Publish Java Application Image to External Registry on Red Hat OpenShift"
draft: false
tags:
- openshift
- java
- maven
- image
date: 2023-12-15
lastmod: 2023-12-15
---

## Introduction:

I came across this blog post a few days ago: [Pushing Application Images to External Registry](https://www.redhat.com/en/blog/pushing-application-images-to-an-external-registry) . It showcases how you can push to some external container registry changing output OpenShift’s BuildConfig. Writing a blog post about it from a Java developer’s perspective sounded like a nice idea to me. Since I’m talking about Java developer experience, I’m going to use [Eclipse JKube](https://www.google.com/url?q=https://github.com/eclipse/jkube&sa=D&source=editors&ust=1702660421800583&usg=AOvVaw065PfRZGFpOjweG5FIqKG-) again to simplify this scenario.

We are going to build a container image in [Red Hat OpenShift](https://www.redhat.com/en/technologies/cloud-computing/openshift) and push that image to an external container registry ([Quay.io](https://quay.io/) in our case) using [OpenShift Maven Plugin](https://eclipse.dev/jkube/docs/openshift-maven-plugin/).

## Prerequisites:

You would need the following things to be able to follow this article:

*   Access to a [Red Hat OpenShift](https://www.redhat.com/en/technologies/cloud-computing/openshift) cluster, you can also use [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox).
*   The [OpenShift command-line interface](https://developers.redhat.com/blog/2021/04/21/access-your-developer-sandbox-for-red-hat-openshift-from-the-command-line#first_stop__the_openshift_dashboard) (CLI), which offers the oc command.
*   A [Java Development Kit](https://adoptopenjdk.net/) (JDK).
*   A text editor.

## Setting up Application:

You can either use an existing project or create a new one. I would be creating a simple Quarkus Application from Quarkus Starter. Select your preferred project `groupId`, `artifactId`, and Java version, and download and unpack the zip file.

Open the `pom.xml` and add [Eclipse JKube](https://github.com/eclipse/jkube)’s [OpenShift Maven Plugin](https://eclipse.dev/jkube/docs/openshift-maven-plugin/) in `<plugins>` section:
```xml
<plugin>
      <groupId>org.eclipse.jkube</groupId>
      <artifactId>openshift-maven-plugin</artifactId>
      <version>1.15.0</version>                                                              
</plugin>
```
Now we should be able to use [OpenShift Maven Plugin](https://eclipse.dev/jkube/docs/openshift-maven-plugin/) in our project.

## Adding Registry Credentials as OpenShift Secret:
Once you've logged into your OpenShift cluster, you need to add Registry authentication credentials as Secret into it. 

You can do that by issuing this command:
```shell
$ oc create secret docker-registry \ 
  --docker-server=quay.io          \ 
  --docker-username=$QUAY_USERNAME \ 
  --docker-password=$QUAY_PASSWORD \ 
  quay-secret                       
secret/quay-secret created
```

## Configuring OpenShift Maven Plugin to Push Image to Quay.io

Default behavior of [OpenShift Maven Plugin](https://eclipse.dev/jkube/docs/openshift-maven-plugin/) is to build and push the container image to
OpenShift's internal registry. In order to override this behavior, we need to provide some configuration. We will add `<configuration>` section in
the plugin declaration to override build type, OpenShift secret to use during OpenShift Build, and image name.


```xml
  <plugin>
    <groupId>org.eclipse.jkube</groupId>
    <artifactId>openshift-maven-plugin</artifactId>
    <version>1.15.0</version>
    <configuration>
        <!-- (1) -->
        <buildOutputKind>DockerImage</buildOutputKind>
        <!-- (2) -->
        <openshiftPushSecret>quay-secret</openshiftPushSecret>
        <generator>
          <config>
            <quarkus>
              <!-- (3) -->
              <name>quay.io/${env.QUAY_USERNAME}/${project.artifactId}:${project.version}</name>
            </quarkus>
          </config>
        </generator>
    </configuration>
  </plugin>
```
1. `buildOutputKind` instructs to use `DockerImage` as output instead of `ImageStreamTag`
2. `openshiftPushSecret` specified the secret to use while doing OpenShift build.
3. [Eclipse JKube](https://github.com/eclipse/jkube) has a concept of generators to build opinionated container images for well known Java frameworks. This configuration instructs 
   JKube to override the default name of image (`group/artifact:version`) to `quay.io/username/projectName:version`.

## Building and Pushing Image to Quay.io

Once you've configured the plugin as per your requirements, you can go ahead and issue [OpenShift Maven Plugin](https://eclipse.dev/jkube/docs/openshift-maven-plugin/) build goal.
This would build a container image and push it to a specified external registry (`quay.io` in our case).
```shell
$ mvn package oc:build
```

You will notice that during Image is pushed as a last step in OpenShift Maven Plugin Build Logs:

```shell
[INFO] oc: Pushing image quay.io/username/quarkus-openshift-quay-image-push:1.0.0-SNAPSHOT ...
[INFO] oc: Pushed 0/3 layers, 1% complete
[INFO] oc: Pushed 1/3 layers, 76% complete
[INFO] oc: Pushed 2/3 layers, 89% complete
[INFO] oc: Pushed 3/3 layers, 100% complete
[INFO] oc: Push successful
[INFO] oc: Build quarkus-openshift-quay-image-push-s2i-5 in status Complete
```

## Conclusion:

In this blog post, you learned how you can leverage on [OpenShift Maven Plugin](https://eclipse.dev/jkube/docs/openshift-maven-plugin/) to seamlessly publish 
your application’s container image to a remote external registry from within your OpenShift cluster. You can also watch 
this video by my colleague [Marc Nuri](https://github.com/manusa) which showcases this in action:

{{< youtube zAIARZ-efxk >}}


You can find code related to this blog post in [this GitHub Repository](https://github.com/rohankanojia-forks/jkube-testing/blob/main/quarkus-openshift-quay-image-push/pom.xml#L40).

To learn more about Eclipse JKube, check these links:

- [Eclipse's JKube documentation](https://www.eclipse.org/jkube/docs/)
- [GitHub issue tracker](https://github.com/eclipse/jkube/issues)
- [StackOverflow](https://stackoverflow.com/questions/tagged/jkube)
- [YouTube channel](https://www.youtube.com/channel/UCpU2tjgpfkTVgeDq-DBSV7A)
- [Twitter](https://twitter.com/jkubeio)
- [Gitter chat](https://app.gitter.im/#/room/#eclipse_jkube:gitter.im)