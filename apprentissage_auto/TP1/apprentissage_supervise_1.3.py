####################################################
#          Apprentissage supervise TP 1            #
#         III - Le jeu de donees Digits           #
#           Alexandre Leonardi                     #
#      alexandre.leonardi@etu.univ-amu.fr          #
####################################################

#Ecrivez un programme qui :
#    -ouvre le jeu de donnees digits,
#    -repartit les donnees en un ensemble d'apprentissage et un ensemble de test (30% pour le test)
#    -choisit par validation croisee sur l'ensemble d'apprentissage un ensemble de voisins kopt optimal
#    -entraine le classifieur des kopt plus proches voisiins sur l'echantillon d'apprentissage
#    -evalue son erreur sur l'echantillon de test
#    -affiche quelques chiffres parmi ceux qui sont mal classes

#imports
from sklearn.datasets import load_digits
import pylab as pl
from sklearn import neighbors
from sklearn.cross_validation import train_test_split
import random
from sklearn.cross_validation import KFold

#Ouverture digits
digits=load_digits()
X=digits.data
Y=digits.target

#Choix du nombre de voisins optimal
kf=KFold(len(X),n_folds=10,shuffle=True)
scores=[]
for k in range(1,30):
    score=0
    clf = neighbors.KNeighborsClassifier(k)
    for learn,test in kf:
        X_train=[X[i] for i in learn]
        Y_train=[Y[i] for i in learn]
        clf.fit(X_train, Y_train)
        X_test=[X[i] for i in test]
        Y_test=[Y[i] for i in test]
        score = score + clf.score(X_test,Y_test)
    scores.append(score)
#Retenir le meilleur k kopt
kopt = scores.index(max(scores))

#Repartition ensemble apprentissage/test
X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())

#Entrainement du classifieur pour les kopt plus proches voisins 
clf = neighbors.KNeighborsClassifier(kopt)
clf.fit(X_train, Y_train)

#Evaluation de l'erreur sur l'echantillon test
print "Score : ",clf.score(X_test,Y_test)

#Affichage des chiffres mal classes
Z=clf.predict(X_test)
print "Nombre d'erreurs : ", len(X[Z!=Y])
pl.matshow(X[Z!=Y].reshape(8,8))
pl.show()
