##############################################
#       Apprentissage supervise TP 1         #
#       I - Jeux de donnees                  #
##############################################

#importation Iris dataset
from sklearn import datasets
iris=datasets.load_iris()

#Executez les commandes suivantes et comprenez ce qu'elles realisent :
len(iris.data)
#help(len)
iris.target_names[0]
iris.target_names[2]
iris.target_names[-1]#Renvoie la derniere case du tableau (il fait un genre de modulo ?)
#iris.target_names[len(iris.target_names)] #Index out of bounds exception
iris.data.shape
iris.data[0]
iris.data[0][1]
iris.data[:,1]

#Executez les commandes suivantes et comprenez ce qu'elles realisent
"""import pylab as pl
X=iris.data
Y=iris.target
x=0
y=1
pl.scatter(X[:,x], X[:,y],c=Y)
pl.show()
#help(pl.scatter)
pl.xlabel(iris.feature_names[x])
pl.ylabel(iris.feature_names[y])
pl.scatter(X[:,x], X[:,y],c=Y)
pl.show()"""

#Une autre methode
"""import pylab as pl
X=iris.data
Y=iris.target
x = 0
y = 1
Y==0#Affiche un tableau de booleens dont la case i vaut true si Y[i]==0
X[Y==0]#Affiche toutes les cases de X d'indice i tq Y[i]==0
X[Y==0][:, x]#Cree un nouveau tableau compose de tous les elements d'indice x (cad 0) parmi la matrice X[Y==0
pl.scatter(X[Y==0][:, x],X[Y==0][:,y],#On prend tous les points appartenant a la classe 0, ca nous donne une matrice. On leur donne une abcisse : pour chaque point l'elt d'indice 0(x) de sa matrice ; l'ordonnee a l'indice 1(y).
color="red",label=iris.target_names[0])
pl.scatter(X[Y==1][:, x],X[Y==1][:, y],
color="green",label=iris.target_names[1])
pl.scatter(X[Y==2][:, x],X[Y==2][:, y],
color="blue",label=iris.target_names[2])
pl.xlabel(iris.feature_names[x])
pl.ylabel(iris.feature_names[y])
pl.legend()
pl.show()"""

#Une troisieme methode
# -*- coding: utf-8 -*-
"""import pylab as pl
from sklearn.datasets import load_iris
iris=load_iris()
X=iris.data
Y=iris.target
x = 0
y = 1
colors=["red","green","blue"]
for i in range(3):
    pl.scatter(X[Y==i][:, x],X[Y==i][:,y],color=colors[i],label=iris.target_names[i])
pl.legend()
pl.xlabel(iris.feature_names[x])
pl.ylabel(iris.feature_names[y])
pl.title(u"Donees Iris - dimension des sepales uniquement")
pl.show()"""

#Les donnees iris sont decrites par 4 attributs. Il y a 6 manieres d'en extraire 2. En modifiant le programme ci-dessus, determinez visuellement le couple d'attributs qui semble le mieux a meme de discriminer les 3 classes d'iris.
import pylab as pl
from sklearn.datasets import load_iris
iris=load_iris()
X=iris.data
Y=iris.target
colors=["red","green","blue"]
for x in range(4):
    for y in range(x+1,4):
        for i in range(3):
            pl.scatter(X[Y==i][:, x],X[Y==i][:,y],color=colors[i],label=iris.target_names[i])
        pl.legend()
        pl.xlabel(iris.feature_names[x])
        pl.ylabel(iris.feature_names[y])
#        pl.title("Test : x=",iris.feature_names[x] + " y=",iris.feature_names[y])
        pl.show()
#La comparaison qui me parait la plus pertinante est celle prenant en compte la longueur et la largeur des petales de chaque iris. En effet, a premiere vue, ce serait celle pour laquelle le moins de points risqueraient d'etre mal places du fait d'un "chevauchement" des nuages de donnees. 
