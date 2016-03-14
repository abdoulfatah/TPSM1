####################################################
#          Apprentissage supervise TP 2            #
#           III - Matrices de confusion            #
#           Alexandre Leonardi                     #
#      alexandre.leonardi@etu.univ-amu.fr          #
####################################################

#imports
from sklearn.datasets import load_iris
from sklearn.cross_validation import train_test_split
from sklearn.metrics import confusion_matrix
from sklearn import tree
iris=load_iris()

#Exemple simple de creation d'une matrice de confusion sur iris
X=iris.data
Y=iris.target
X_train,X_test,Y_train,Y_test = train_test_split(X,Y,random_state=0)
clf=tree.DecisionTreeClassifier()
clf=clf.fit(X_train,Y_train)
Y_pred=clf.predict(X_test)

#La valeur de la case (i,j) est le nombre d'elements de la classe i (ligne) que le classifieur a mis dans la classe j (colonne)
cm=confusion_matrix(Y_test,Y_pred)
print cm
help(confusion_matrix)
