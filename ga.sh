#!/bin/sh -
#
# Gestion de cours de programme d'etudes.


# Nom de fichier pour depot par defaut.
DEPOT_DEFAUT=.cours.txt

##########################################################################
# Fonctions pour debogage et traitement des erreurs.
##########################################################################

# Pour generer des traces de debogage avec la function debug, il
# suffit de supprimer le <<#>> au debut de la ligne suivante.
#DEBUG=1

#-------
# Affiche une trace de deboggage.
#
# Arguments: [chaine...]
#-------
function debug {
    [[ $DEBUG ]] || return

    echo -n "[debug] "
    for arg in "$@"
    do
        echo -n "'$arg' "
    done
    echo ""
}

#-------
# Affiche un message d'erreur.
#
# Arguments: msg
#-------
function erreur {
    msg=$1

    # A COMPLETER: Les erreurs doivent etre emises stderr...
    # mais ce n'est pas le cas pour l'instant!
    >&2 echo "*** Erreur: $msg"
    >&2 echo ""

    # On emet le message d'aide si commande fournie invalide.
    # Par contre, ce message doit etre emis sur stdout.
    [[ ! $msg =~ Commande\ inconnue ]] || aide
    
    exit 1
}


##########################################################################
# Fonction d'aide: fournie, pour uniformite.
#
# Arguments: Aucun
#
# Emet l'information sur stdout
##########################################################################
function aide {
    cat <<EOF
NOM
  $0 -- Script pour gestion academique (banque de cours)

SYNOPSIS
  $0 [--depot=fich] commande [options-commande] [argument...]

COMMANDES
  aide          - Emet la liste des commandes
  ajouter       - Ajoute un cours dans la banque de cours 
                  (les prealables doivent exister)
  desactiver    - Rend inactif un cours actif 
                  (ne peut plus etre utilise comme nouveau prealable)
  init          - Cree une nouvelle base de donnees pour gerer des cours
                  (dans './$DEPOT_DEFAUT' si --depot n'est pas specifie)
  lister        - Liste l'ensemble des cours de la banque de cours 
                  (ordre croissant de sigle)
  nb_credits    - Nombre total de credits pour les cours indiques
  prealables    - Liste l'ensemble des prealables d'un cours
                  (par defaut: les prealables directs seulement)
  reactiver     - Rend actif un cours inactif
  supprimer     - Supprime un cours de la banque de cours
  trouver       - Trouve les cours qui matchent un motif
EOF
}

##########################################################################
# Fonctions pour manipulation du depot.
#
# Fournies pour simplifier le devoir et assurer au depart un
# fonctionnement minimal du logiciel.
##########################################################################

#-------
# Verifie que le depot indique existe, sinon signale une erreur.
#
# Arguments: depot
#-------
function assert_depot_existe {
    depot=$1
    [[ -f $depot ]] || erreur "Le fichier '$depot' n'existe pas!"
}


#-------
# Commande init.
#
# Arguments:  depot [--detruire]
#
# Erreurs:
#  - Le depot existe deja et l'option --detruire n'a pas ete indiquee
#-------
function init {
    depot=$1;
    arguments_utilises=0

    if [[ $2 =~ ^--detruire$ ]]; then
		detruire=true
		((arguments_utilises++))
	fi

    if [[ -f $depot ]]; then
		[[ $detruire == true ]] || erreur "Le fichier '$depot' existe. Si vous voulez le detruire, utilisez 'init --detruire'."
        \rm -f $depot
    fi

    # On 'cree' le fichier vide.
    touch $depot

    return $arguments_utilises
}

##########################################################################
# Les fonctions pour les diverses commandes de l'application.
#
# A COMPLETER!
#
##########################################################################


# Separateur pour les champs d'un enregistrement specificant un cours.
readonly SEPARATEUR=,
readonly SEP=$SEPARATEUR # Alias, pour alleger le code

# Separateur pour les prealables d'un cours.
readonly SEPARATEUR_PREALABLES=:

#-------
# Commande lister
#
# Arguments: depot [--avec_inactifs]
#
# Erreurs:
# - depot inexistant
#-------
function lister {
	arguments_utilises=0
	assert_depot_existe $1
	
	if [[ $2 =~ ^--avec_inactifs$ ]]; then
		inactif=true
		((arguments_utilises++))
	fi

	awk -F"$SEP" -v inactif="$inactif" '
		/,ACTIF$/ { print $1, "\""$2"\"", "\("$4"\)" }
		/,INACTIF$/ && inactif=="true" { print $1"?", "\""$2"\"", "\("$4"\)"}
	' $1 2> /dev/null | sort

	return $arguments_utilises
}


#-------
# Commande ajouter
#
# Arguments: depot sigle titre nb_credits [prealable...]
#
# Erreurs:
# - depot inexistant
# - nombre insuffisant d'arguments
# - sigle de forme invalide ou inexistant
# - sigles des prealables de forme invalide ou inexistants
# - cours avec meme sigle existe deja
#-------


function ajouter {
	assert_depot_existe $1
	[[ $# -ge 4 ]] || erreur "Nombre insuffisant d'arguments"
	valider_sigle $2
	! assert_sigle_existe $1 $2 --avec_inactifs || erreur "Un cours avec le meme sigle existe deja"
	
	arguments_utilises=3
	chaine="$2,$3,$4,"
	fichier=$1	
	shift 4

	while [[ $# != 0 ]]
	do
		valider_sigle $1
		assert_sigle_existe $fichier $1 || erreur "Prealable invalide: '$1'"
		chaine="$chaine$1"
		shift
		[[ $# == 0 ]] || chaine="$chaine$SEPARATEUR_PREALABLES"
		((arguments_utilises++))
	done

	chaine="$chaine,ACTIF" 
	echo $chaine >> $fichier
	
    return $arguments_utilises
}


#-------
# Commande trouver
#
# Arguments: depot [--avec_inactifs] [--cle_tri=sigle|titre] [--format=un_format] motif
# 
# Erreurs:
# - depot inexistant
# - nombre incorrect d'arguments
# - cle_tri de valeur invalide
# - item de format invalide
#-------
function trouver {
	assert_depot_existe $1
	[[ $# -ge 2 ]] || erreur "Nombre insuffisant d'arguments"
	depot=$1; shift
	arguments_utilises=1

    if [[ $1 =~ ^--avec_inactifs$ ]]; then
		((arguments_utilises++))
		shift
	fi

	if [[ $1 =~ ^--cle_tri= ]]; then
		tri=${1##--cle_tri=}
		((arguments_utilises++))
		shift	
	fi

	if [[ $1 =~ ^--format= ]]; then
		format=${1##--format=}
		((arguments_utilises++))
		shift
	fi

	commande="grep -h -i '$1' $depot"

	if ! [[ $inactif == true ]]; then
		commande="$commande | grep -v ,INACTIF$"
	fi

	case $tri in 
		sigle) commande="$commande | sort -t\"$SEP\"";;
		titre) commande="$commande | sort -t\"$SEP\" -k2";;
		*);;
	esac
	
	eval $commande

	return $arguments_utilises
}

#-------
# Commande nb_credits
#
# Arguments: depot [sigle...]
# 
# Erreurs:
# - depot inexistant
# - sigle inexistant
#-------
function nb_credits {
	assert_depot_existe $1
    arguments_utilises=0
	total_credits=0
	fichier=$1
	shift

	while [[ $# != 0 ]]
	do
		assert_sigle_existe $fichier $1 || erreur "Aucun cours: $1"
		credit=$(awk -F"$SEP" -v sigle="$1" '$1==sigle {print $3}' $fichier)
		((total_credits += $credit))
		shift
		((arguments_utilises++))
	done

	echo $total_credits

	return $arguments_utilises
}


#-------
# Commande supprimer
#
# Arguments: depot sigle
# 
# Erreurs:
# - depot inexistant
# - nombre incorrect d'arguments
# - sigle inexistant
#-------
function supprimer {
	assert_depot_existe $1
    [[ $#==2 ]] || erreur "Nombre incorrect d'arguments"
	assert_sigle_existe $1 $2 --avec_inactifs || erreur "Aucun cours: $2"

	sed -i "/^$2/d" $1

	return 1
}


#-------
# Commande desactiver
#
# Arguments: depot sigle
# 
# Erreurs:
# - depot inexistant
# - nombre incorrect d'arguments
# - sigle inexistant
# - cours deja inactif
#-------
function desactiver {
	assert_depot_existe $1
    [[ $#==2 ]] || erreur "Nombre incorrect d'arguments"
	assert_sigle_existe $1 $2 --avec_inactifs || erreur "Aucun cours: $2"
	
	statut=$(awk -F"$SEP" -v sigle="$2" '$1==sigle {print $5}' $1)
	[[ $statut == "ACTIF" ]] || erreur "Cours deja inactif: $2"

	sed -i "/^$2,/ s/ACTIF/INACTIF/" $1

	return 1
}

#-------
# Commande reactiver
#
# Arguments: depot sigle
# 
# Erreurs:
# - depot inexistantt
# - nombre incorrect d'arguments
# - sigle inexistant
# - cours deja actif
#-------
function reactiver {
	assert_depot_existe $1
    [[ $#==2 ]] || erreur "Nombre incorrect d'arguments"
	assert_sigle_existe $1 $2 --avec_inactifs || erreur "Aucun cours: $2"
	
	statut=$(awk -F"$SEP" -v sigle="$2" '$1==sigle {print $5}' $1)
	[[ $statut == "INACTIF" ]] || erreur "Cours deja actif: $2"

	sed -i "/^$2,/ s/INACTIF/ACTIF/" $1

	return 1
}


#-------
# Commande prealables
#
# Arguments: depot [--directs|--tous] sigle
#
# Erreurs:
# - depot inexistant
# - nombre incorrect d'arguments
# - sigle inexistant
#-------
function prealables {
	[[ $# -ge 2 ]] || erreur "Nombre incorrect d'arguments"
	assert_depot_existe $1
	depot=$1; shift
	arguments_utilises=1

	if [[ $1 =~ ^--tous$ ]]; then
		tous=true
		((arguments_utilises++))
		shift
	fi 

	assert_sigle_existe $depot $1 || erreur "Aucun cours: $1"

	IFS=$SEPARATEUR_PREALABLES read -a array_initiale <<< $(awk -F"$SEP" -v sigle=$1 '$1==sigle {print $4}' $depot)

	if [[ $tous == true ]]; then
		for i in "${array_initiale[@]}"
		do
			read -a array_secondaire <<< $(prealables $depot --tous $i)
			for j in "${array_secondaire[@]}"
			do
				array_initiale[${#array_initiale[@]}]=$j
			done
		done
	fi

	array_ordonnee=($(
		for i in "${array_initiale[@]}"
		do
			echo $i
		done | sort -u)
	)

	for i in "${array_ordonnee[@]}"
	do
		echo $i
	done 

    return $arguments_utilises
}

##########################################################################
# FONCTIONS SECONDAIRES
##########################################################################

#------
# Fonction valider_sigle
#
# Arguments: sigle
#
# Valide le format du sigle
#------

function valider_sigle {
	[[ $1 =~ [A-Z]{3}[0-9]{4} ]] || erreur "Sigle incorrect: $1"
}

#------
# Fonction assert_sigle_existe
#
# Arguments: depot sigle [--avec_inactifs]
#
# Verifie que le cours est present dans le depot
#-----

function assert_sigle_existe {
	[[ $3 =~ ^--avec_inactifs$ ]]
	avec_inactifs=$?

	if [[ $avec_inactifs == 0 ]]; then
		grep -q ^$2, $1
	else
		grep ^$2, $1 | grep -qv ,INACTIF$
	fi

	return $?
}

##########################################################################
# Le programme principal
#
# La strategie utilisee pour uniformiser le trairement des commande
# est la suivante : Une commande est mise en oeuvre par une fonction
# auxiliaire du meme nom que la commande. Cette fonction retourne
# comme statut le nombre d'arguments ou d'options (du programme
# principal) utilises par la commande --- mais  on ne compte pas l'argument
# $depot, transmis a chacune des fonctions.
#
# Ceci permet par la suite, dans le corps de la fonction principale,
# de "shifter" les arguments et, donc, de verifier si des arguments
# superflus ont ete fournis.
#
##########################################################################

function main {
  	# On definit le depot a utiliser.
  	# A COMPLETER: il faut verifier si le flag --depot=... a ete specifie.
  	# Si oui, il faut modifier depot en consequence!
  
	if [[ $1 =~ ^--depot=* ]]; then
		depot=${1##--depot=}
		shift
	else
		depot=$DEPOT_DEFAUT
	fi

  	debug "On utilise le depot suivant:", $depot

  	# On analyse la commande (= dispatcher).
  	commande=$1
  	shift
  	case $commande in
		''|aide)
        aide;;

      	ajouter|\
      	desactiver|\
      	init|\
      	lister|\
      	nb_credits|\
      	prealables|\
      	reactiver|\
      	supprimer|\
		assert_sigle_existe|\
      	trouver)
          	$commande $depot "$@";;

      	*) 
          	erreur "Commande inconnue: '$commande'";;
  	esac
  	shift $?

  	[[ $# == 0 ]] || erreur "Argument(s) en trop: '$@'"
}

main "$@"
exit 0
