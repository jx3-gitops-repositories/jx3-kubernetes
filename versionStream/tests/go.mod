module github.com/jenkins-x/jxr-versions

go 1.15

require (
	github.com/jenkins-x-plugins/jx-secret v0.1.50
	github.com/jenkins-x-plugins/secretfacade v0.1.2
	github.com/jenkins-x/jx-api/v4 v4.1.3
	github.com/jenkins-x/jx-helpers/v3 v3.0.125
	k8s.io/api v0.21.2
	k8s.io/apimachinery v0.21.2
)

replace (
	k8s.io/api => k8s.io/api v0.20.2
	k8s.io/apimachinery => k8s.io/apimachinery v0.20.2
	k8s.io/client-go => k8s.io/client-go v0.20.2
)
