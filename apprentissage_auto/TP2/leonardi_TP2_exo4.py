from __future__ import print_function

####################################################
#          Apprentissage supervise TP 2            #
#   IV-Intervalle de confiance pour l'erreur       #
#         estimee d'un classifieur                 #
#           Alexandre Leonardi                     #
#      alexandre.leonardi@etu.univ-amu.fr          #
####################################################

#imports
from sklearn.datasets import make_classification
from sklearn.datasets import load_iris
from sklearn import tree
from sklearn.cross_validation import train_test_split
import random
import math
iris=load_iris()

#Generation des exemples
X,Y=make_classification(n_samples=100000,n_informative=15,n_features=20,n_classes=3)

#Repartition : X_2 contiendra 95% des exemples contenus dans X et X_1 5%
X_2,X_1,Y_2,Y_1=train_test_split(X,Y,test_size=0.05,random_state=random.seed())

#Repartition de X_1 en X_app (80%) et X_test (20%)
X_app,X_test,Y_app,Y_test=train_test_split(X_1,Y_1,test_size=0.2,random_state=random.seed())

#Entrainer un arbre de decision sur XY_app et le tester sur XY_test
clf=tree.DecisionTreeClassifier()
clf=clf.fit(X_app,Y_app)
print("X_test erreur : ",end="")
e=1-clf.score(X_test,Y_test)
print("%1.2f" %e)

#Affichage de l'intervalle de confiance a 95%
emin=e-1.96*math.sqrt(e*(1-e)/len(X_test))
emax=e+1.96*math.sqrt(e*(1-e)/len(X_test))
print("Intervalle de confiance I a 95% ",end="")
print("[%1.2f ; %1.2f]" %(emin, emax))

#Erreur estimee f sur X_2 Y_2
print("X_2 erreur : ",end="")
f=1-clf.score(X_2,Y_2)
print("%1.2f" %f)
if(f>=emin and f<=emax): print("f dans I")
else: print("f pas dans I")

#L'effectif de X_2  est important, pourquoi ?
#Avoir un effectif eleve, ici 95 000 exemples, permet de "lisser" les valeurs et d'eviter d'avoir des erreurs statistiques qui feraient sortir le resultat de l'intervalle de confiance


#Reiterer 100 fois l'experience et compter le nombre de fois ou f n'est pas dans I
endehors=0
for i in range(0,100):
    e=1-clf.score(X_test,Y_test)
    emin=e-1.96*math.sqrt(e*(1-e)/len(X_test))
    emax=e+1.96*math.sqrt(e*(1-e)/len(X_test))
    f=1-clf.score(X_2,Y_2)
    if(f<emin or f>emax):endehors+=1
print("Nb  de f en-dehors de i : %d/100" %endehors)
#On s'attend a trouver une valeur tres faible voire 0 car le grand effectif de X_2 permet d'avoir une faible chance de s'ecarter des valeurs moyennes
