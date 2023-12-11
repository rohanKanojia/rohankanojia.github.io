---
title: "My First Post"
draft: false
---

# First Blog

---
Body

```java
try (KubernetesClient client = new KubernetesClientBuilder().build()) {
  ClusterCIDR clusterCIDR = new ClusterCIDRBuilder()
      .withNewMetadata()
      .withName("test-clustercidr")
      .endMetadata()
      .withNewSpec()
      .withIpv4("10.0.0.0/8")
      .withIpv6("2001:db8::/64")
      .withPerNodeHostBits(4)
      .withNodeSelector(new NodeSelectorBuilder()
          .withNodeSelectorTerms(Collections.singletonList(new NodeSelectorTermBuilder()
              .addNewMatchField()
              .withKey("metadata.name")
              .withOperator("In")
              .withValues("test-name")
              .endMatchField()
              .addNewMatchExpression()
              .withKey("metadata.name")
              .withOperator("In")
              .withValues("test-name")
              .endMatchExpression()
              .build()))
          .build())
      .endSpec()
      .build();

  client.network().v1alpha1().clusterCIDRs().resource(clusterCIDR).serverSideApply();
  KubernetesResourceList<ClusterCIDR> clusterCIDRKubernetesResourceList = client.network().v1alpha1().clusterCIDRs()
      .list();
  System.out.printf("%d ClusterCIDR found%n", clusterCIDRKubernetesResourceList.getItems().size());
  client.network().v1alpha1().clusterCIDRs().resource(clusterCIDR).delete();
}
```
