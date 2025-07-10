# Upgrade of API version for Tekton Pipelines to v1

With this upgrade the API version of Tekton Pipeline resources (like pipeline runs) are updated from tekton.dev/v1beta1
to tekton.dev/v1.

If the Kubernetes cluster you now upgrade does not have Tekton Pipelines installed this will naturally not have any 
effect. A typical case if this is a remote cluster.

## Potential problems with conversion

In the Jenkins X cluster upgrade process any changes to custom resource definitions are applied first. In this case 
this will trigger the Kubernetes cluster to ask tekton-pipelines-webhook to convert existing tekton pipeline 
resources in the cluster. At this time the tekton-pipelines-webhook deployment is an old version which include bugs 
that cause some old pipeline runs to start executing again. This can cause confusion and problems, especially if a
release pipeline for an old version of an application is run again.

The simplest way to avoid this is to manually delete existing pipeline runs before doing this upgrade. This can be 
done by running 

```
kubectl delete piplinerun --all -namespace jx
```

## Existing pipelines in application repositories

So far the supported API version of the pipelines in the .ligthouse directory of your application respositories have 
been tekton.dev/v1beta1. From now on tekton.dev/v1 is also supported. Any pipelines with version tekton.dev/v1beta1 
will be automatically converted to tekton.dev/v1 when read by lighthouse. After the Tekton Pipelines project remove 
support for this conversion it will be removed from lighthouse as well. But before that tools to convert the 
pipelines in .lighthouse will be made available.

## Change in functionality

The version of Tekton Pipelines is upgraded from 0.42.0 to 1.1.0. 
You can find the release notes here: https://github.com/tektoncd/pipeline/releases