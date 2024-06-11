#!/bin/bash

build() {
    old_build=$(echo $1 | cut -d'.' -f 3)
    new_build=$((old_build + 1))

    result="$(echo $1 | cut -d'.' -f1-2).$new_build"
    
    grep -v '^VERSION=' config > config.tmp
    (
        cat config.tmp
        echo -n "VERSION=$result"
    ) > config
    rm config.tmp
}

minor() {
    old_build=$(echo $1 | cut -d'.' -f 2)
    new_build=$((old_build + 1))

    result="$(echo $1 | cut -d'.' -f1).$new_build.0"
    
    grep -v '^VERSION=' config > config.tmp
    (
        cat config.tmp
        echo -n "VERSION=$result"
    ) > config
    rm config.tmp
}

major() {
    old_build=$(echo $1 | cut -d'.' -f 1)
    new_build=$((old_build + 1))

    result="$new_build.0.0"
    
    grep -v '^VERSION=' config > config.tmp
    (
        cat config.tmp
        echo -n "VERSION=$result"
    ) > config
    rm config.tmp
}

version=$(cat config | egrep ^VERSION= | colrm 1 8)
if [ $# == 1 ] 
then
    if [ $1 == "--build" ]
    then
        echo "Version build"
        build $version
    elif [ $1 == "--minor" ]
    then
        echo "Version minor"
        minor $version
    elif [ $1 == "--major" ]
    then
        echo "Version major"
        major $version
    fi
fi
nomClient=$(cat config | egrep ^CLIENT= | colrm 1 7 | tr [:upper:] [:lower:] | tr ' ' '_')
version=$(cat config | egrep ^VERSION= | colrm 1 8)
mkdir rendu

echo "Création de clock en étant monté sur le volume"
echo
docker volume create sae103
docker container run --name sae103-forever -dv sae103:/work clock > tempIds
idClock=$(cat tempIds)
echo
echo

# copie des fichiers 
echo "Copie des fichiers dans le volume monté"
echo
for file in `ls *.c`; do 
    docker cp $file sae103-forever:/work/ 
done

docker cp "DOC_UTILISATEUR.md" sae103-forever:/work/
docker cp "gendoc-tech.php" sae103-forever:/work/
docker cp "gendoc-user.php" sae103-forever:/work/
docker cp "config" sae103-forever:/work/
echo
echo

# generation de la doc
echo "Génération des docs"
echo
docker container run --rm -tv sae103:/work sae103-php php -f /work/gendoc-tech.php > "./rendu/doc-technique-$version.html" # ne marche pas sans une version interactive
docker container run --rm -tv sae103:/work sae103-php php -f /work/gendoc-user.php > "./rendu/doc-utilisateur-$version.html" # ne marche pas sans une version interactive
docker cp ./rendu/doc-technique-$version.html sae103-forever:/work/
docker cp ./rendu/doc-utilisateur-$version.html sae103-forever:/work/
echo
echo

# conversion en PDF
echo "Génération des pdfs"
echo
docker container run --rm -tv  sae103:/work sae103-html2pdf "html2pdf doc-technique-$version.html doc-technique-$version.pdf" > temp 2>&1 # ne marche pas
docker container run --rm -tv sae103:/work sae103-html2pdf "html2pdf doc-utilisateur-$version.html doc-utilisateur-$version.pdf"  > temp 2>&1 # ne marche pas
rm temp
echo 

# copie pour les tests
echo "Copie des fichiers hors du volume"
echo
docker cp sae103-forever:/work/doc-utilisateur-$version.html ./rendu/
docker cp sae103-forever:/work/doc-technique-$version.html ./rendu/
docker cp sae103-forever:/work/doc-utilisateur-$version.pdf ./rendu/
docker cp sae103-forever:/work/doc-technique-$version.pdf ./rendu/
echo
echo

# Création de l'archive
echo "Création de l'archive"
echo
for file in `ls *.c`; do 
    cp $file ./rendu/ 
done
tar czvf $nomClient-$version.tgz rendu
echo
echo

# arret des conteneurs et du volume

docker container stop $idClock
# docker container rm $idClock
docker container prune <<< "y"
docker volume rm sae103