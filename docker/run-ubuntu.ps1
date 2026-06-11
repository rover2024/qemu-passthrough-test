param(
    [string]$Image = "ubuntu:22.04",
    [string]$ContainerName = "passthrough-container"
)

docker run --rm -it `
    --name $ContainerName `
    -v "${PSScriptRoot}:/home/user/docker" `
    -w /home/user/docker `
    $Image bash
