from __future__ import print_function

####################################################
#          Apprentissage supervise TP 2            #
#            II- Arbes de decision                 #
#           Alexandre Leonardi                     #
#      alexandre.leonardi@etu.univ-amu.fr          #
####################################################

#imports
from sklearn.datasets import make_classification
from sklearn.datasets import load_iris
from sklearn import tree
from sklearn.cross_validation import train_test_split
import random
import pylab as pl
iris=load_iris()

#print clf.predict(iris.data[50,:])
#print clf.score(iris.data,iris.target)

#Ecrivez un programme qui ouvre Iris, appprend un arbre en utilisant le parametrage par defaut. Combien l'arbre a-t-il de feuilles ? Faire decroitre le nombre de feuilles de 9 a 3.
clf=tree.DecisionTreeClassifier()
clf=clf.fit(iris.data,iris.target)
tree.export_graphviz(clf, out_file="TP2prog11.dot")
#clf=tree.DecisionTreeClassifier(max_leaf_nodes=3)
#clf=clf.fit(iris.data,iris.target)
#tree.export_graphviz(clf, out_file="TP2prog12.dot")

#Ecrivez un programme qui ouvre Iris, apprend un premier arbre de decision en utilisant le critere de Gini, puis un second en utilisant l'entropie.
clf=tree.DecisionTreeClassifier()
clf=clf.fit(iris.data,iris.target)
tree.export_graphviz(clf,out_file="TP2prog21.dot")
clf=tree.DecisionTreeClassifier(criterion='entropy')
clf=clf.fit(iris.data,iris.target)
tree.export_graphviz(clf,out_file="TP2prog22.dot")

#Ecrivez un programme qui cree un jeu de donnees, repartit les donnees en un ensemble d'apprentissage et un ensemble de test, apprend un arbre de decision sur l'echantillon d'apprentissage, puis affecte le score de l'arbre appris sur l'echantillon d'apprentissage puis sur l'ensemble de test. Que constatez-vous ?
X,Y=make_classification(n_samples=100000,n_features=20,n_informative=15,n_classes=3)
X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())
for i in range(1,41):
    #clf=tree.DecisionTreeClassifier(max_leaf_nodes=500*i)
    clf=tree.DecisionTreeClassifier(max_depth=i)
    clf=clf.fit(X_train,Y_train)
    #print("Feuilles max %d : " %(500*i),end="")
    print("Prof %d : " %i,end="")
    print("%1.2f" %(clf.score(X_test,Y_test)))
#On constate que le score  optimal n'est pas celui de la plus grande profondeur :il est atteint pour environ une profondeur de 12 a 19
#Cela veut sans doute dire qu'en utilisant une profondeur plus elevee, le classifieur fait de l'apprentissage par coeur sur les donnees d'apprentissage et est donc moins performant sur les donnees de test
