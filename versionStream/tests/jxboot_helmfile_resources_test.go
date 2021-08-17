package main

import (
	v1 "github.com/jenkins-x-plugins/jx-secret/pkg/apis/external/v1"
	"github.com/jenkins-x-plugins/secretfacade/pkg/secretstore"
	"github.com/jenkins-x/jx-helpers/v3/pkg/gitclient/giturl"
	"path/filepath"
	"testing"

	"github.com/jenkins-x-plugins/jx-secret/pkg/cmd/populate/templatertesting"
	config "github.com/jenkins-x/jx-api/v4/pkg/apis/core/v4beta1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

var (
	// generateTestOutput enable to regenerate the expected output
	generateTestOutput = true

	ns = "jx"
)

func TestSecretSchemaTemplatesMavenSettings(t *testing.T) {
	testSecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "jx-boot",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"username": []byte("gitoperatorUsername"),
				"password": []byte("gitoperatorpassword"),
			},
		},
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "tekton-git",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"username": []byte("gitoperatorUsername"),
				"password": []byte("gitoperatorpassword"),
			},
		},

		// some other secrets used for templating the jenkins-maven-settings Secret
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "nexus",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"password": []byte("my-nexus-password"),
			},
		},
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "sonatype",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"username": []byte("my-sonatype-username"),
				"password": []byte("my-sonatype-password"),
			},
		},
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "gpg",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"passphrase": []byte("my-secret-gpg-passphrase"),
			},
		},
	}

	testCases := []templatertesting.TestCase{
		{
			TestName:   "custom",
			ObjectName: "jenkins-maven-settings",
			Property:   "settings.xml",
			Format:     "xml",
			Requirements: &config.RequirementsConfig{
				Repository: "custom",
				Cluster: config.ClusterConfig{
					Provider:    "gke",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
				Repositories: &config.RepositoryConfig{
					Maven: &config.MavenRepositoryConfig{
						ReleaseURL:  "https://maven.acme.com/myowner/myrepo/",
						SnapshotURL: "https://maven.acme.com/myowner/mysnapshots/",
					},
				},
			},
		},
		{
			TestName:   "github",
			ObjectName: "jenkins-maven-settings",
			Property:   "settings.xml",
			Format:     "xml",
			Requirements: &config.RequirementsConfig{
				Repository: "github",
				Cluster: config.ClusterConfig{
					Provider:    "gke",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
				Repositories: &config.RepositoryConfig{
					Maven: &config.MavenRepositoryConfig{
						ReleaseURL:  "https://maven.pkg.github.com/myowner/myrepo/",
						SnapshotURL: "https://maven.pkg.github.com/myowner/mysnapshots/",
					},
				},
			},
			ExternalSecrets: []templatertesting.ExternalSecret{
				{
					Location: "tekton-git",
					Name:     "tekton-git",
					Value: secretstore.SecretValue{
						Value: "cheese",
						PropertyValues: map[string]string{
							"username": "gitoperatorUsername",
							"password": "gitoperatorpassword",
						},
						Overwrite: false,
					},
					ExternalSecret: v1.ExternalSecret{
						ObjectMeta: metav1.ObjectMeta{
							Name:      "tekton-git",
							Namespace: ns,
						},
						Spec: v1.ExternalSecretSpec{
							BackendType: "local",
							Data: []v1.Data{
								{
									Name:     "username",
									Key:      "tekton-git",
									Property: "username",
								},
								{
									Name:     "password",
									Key:      "tekton-git",
									Property: "password",
								},
							},
							Template: v1.Template{},
						},
					},
				},
			},
		},
		{
			TestName:   "nexus",
			ObjectName: "jenkins-maven-settings",
			Property:   "settings.xml",
			Format:     "xml",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					Provider:    "gke",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "none",
			ObjectName: "jenkins-maven-settings",
			Property:   "settings.xml",
			Format:     "xml",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					Provider:    "docker",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
	}
	if generateTestOutput {
		for i := range testCases {
			testCases[i].GenerateTestOutput = true
		}
	}
	runner := templatertesting.Runner{
		TestCases:   testCases,
		SchemaFile:  filepath.Join("..", "charts", "jxgh", "jxboot-helmfile-resources", "secret-schema.yaml"),
		Namespace:   ns,
		KubeObjects: testSecrets,
	}
	runner.Run(t)
}

func TestSecretSchemaTemplatesContainerRegistry(t *testing.T) {
	testSecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "jx-boot",
				Namespace: "jx-git-operator",
			},
			Data: map[string][]byte{
				"username": []byte("gitoperatorUsername"),
				"password": []byte("gitoperatorpassword"),
			},
		}}

	myRegistrySecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "container-registry-auth",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"url":      []byte("my-registry"),
				"username": []byte("my-registry-user"),
				"password": []byte("my-registry-pwd"),
			},
		}}

	anotherRegistrySecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "container-registry-auth",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"url":      []byte("another-registry"),
				"username": []byte("another-registry-user"),
				"password": []byte("another-registry-pwd"),
			},
		}}

	testCases := []templatertesting.TestCase{
		{
			TestName:   "aks",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "aks-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: myRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "aks-another-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: anotherRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "aws",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aws",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "aws-other-git",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   "https://git.myserver.com",
					Provider:    "aws",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "eks",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "eks-other-git",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   "https://git.myserver.com",
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-my-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: myRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-my-registry-secret-other-git",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: myRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   "https://git.myserver.com",
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-another-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: anotherRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-use-ecr-with-registry",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: anotherRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "gke",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "gke",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "minikube",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "minikube",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
	}
	if generateTestOutput {
		for i := range testCases {
			testCases[i].GenerateTestOutput = true
		}
	}
	runner := templatertesting.Runner{
		TestCases:   testCases,
		SchemaFile:  filepath.Join("..", "charts", "jxgh", "jxboot-helmfile-resources", "secret-schema.yaml"),
		Namespace:   ns,
		KubeObjects: testSecrets,
	}
	runner.Run(t)
}

func TestSecretSchemaTemplatesBucketRepo(t *testing.T) {
	testSecrets := []runtime.Object{}

	testCases := []templatertesting.TestCase{
		{
			TestName:   "bucketrepo",
			ObjectName: "bucketrepo-config",
			Property:   "config.yaml",
			Format:     "yaml",
			Requirements: &config.RequirementsConfig{
				Repository: "bucketrepo",
				Cluster: config.ClusterConfig{
					Provider:    "minikube",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
	}
	if generateTestOutput {
		for i := range testCases {
			testCases[i].GenerateTestOutput = true
		}
	}
	runner := templatertesting.Runner{
		TestCases:   testCases,
		SchemaFile:  filepath.Join("..", "charts", "jxgh", "bucketrepo", "secret-schema.yaml"),
		Namespace:   ns,
		KubeObjects: testSecrets,
	}
	runner.Run(t)
}
