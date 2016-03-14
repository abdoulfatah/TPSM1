####################################################
#          Apprentissage supervise TP 1            #
#II - Classification par les k-plus proches voisins#
####################################################

#Imports
from sklearn import datasets
iris=datasets.load_iris()
from sklearn import neighbors
from sklearn.cross_validation import train_test_split
import random # pour pouvoir utiliser un generateur de nombres aleatoires
from sklearn.cross_validation import KFold

#Ecrivez un programme qui ouvre le jeu de donnees iris, entraine un classifieur des k plus proches voisins sur ce jeu de donnees et affiche le score sur l'echantillon d'apprentissage. 
X=iris.data
Y=iris.target
nb_voisins = 15

"""#help(neighbors.KNeighborsClassifier)
clf = neighbors.KNeighborsClassifier(nb_voisins)
#help(clf.fit)
clf.fit(X,Y)
#help(clf.predict)
print clf.predict([ 5.4,  3.2,  1.6,  0.4])
print clf.predict_proba([ 5.4,  3.2,  1.6,  0.4])
print clf.score(X,Y)
Z = clf.predict(X)
print X[Z!=Y]"""

#Evaluation de l'erreur du classifieur appris
#Donnees optimistes quand apprentissage par coeur 
#Donnees pessimistes car pas assez d'infos pour avoir une classification efficace

#Ecrivez un programme qui ouve le jeu de donnees iris, repartit les donnees en un ensemble d'apprentissage et un ensemble de test, entraine un classifieur des 15 plus proches voisins sur l'echantillon d'apprentissage et evalue son erreur sur l'echantillon de test
X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())
clf = neighbors.KNeighborsClassifier(nb_voisins)
clf.fit(X_train,Y_train)
#print clf.score(X_test,Y_test)

#Selection de modele
#On prend k=15 car cela represente 15% de l'ensemble de donnees total, mais l'ideal serait de faire des tests empiriques pour trouver la meilleure valeur.


#Etudiez et executez le programme ci-dessous : 
X=iris.data
Y=iris.target
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
#print scores
print "meilleure valeur pour k : ",scores.index(max(scores))
print "meilleur  score : ",max(scores)

#Que se passe-t-il si l'on remplace shuffle=True par shuffle=False ?
#Le jeu de test ne sera plus aleatoire parmi l'ensemble des donnees disponibles, les jeux de tests se suivront au sein de l'ensemble des donnees disponibles, cela donnera des tests moins representatifs.
