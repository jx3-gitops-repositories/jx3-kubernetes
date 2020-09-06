module github.com/jenkins-x/jxr-versions

go 1.13

require (
	github.com/jenkins-x/jx-api v0.0.17
	github.com/jenkins-x/jx-secret v0.0.88
	k8s.io/api v0.17.6
	k8s.io/apimachinery v0.17.6
)

replace (
	github.com/Azure/go-autorest => github.com/Azure/go-autorest v13.3.1+incompatible

	github.com/jenkins-x/jx-secret => /workspace/go/src/github.com/jenkins-x/jx-secret

	k8s.io/api => k8s.io/api v0.17.2
	k8s.io/apimachinery => k8s.io/apimachinery v0.17.2
	k8s.io/client-go => k8s.io/client-go v0.16.5
)
