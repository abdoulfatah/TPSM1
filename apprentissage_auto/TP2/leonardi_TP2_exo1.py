####################################################
#          Apprentissage supervise TP 2            #
#         I - Jeux de donnees artificiels          #
#           Alexandre Leonardi                     #
#      alexandre.leonardi@etu.univ-amu.fr          #
####################################################

#imports
from sklearn.datasets import make_classification
import pylab as pl

#Creez un jeu de donnees de 200 exemples avec une partie descriptive en dimension 2(2 features) et 3 classes. Visualisez-le. 
X,Y=make_classification(n_samples=200,n_features=2,n_redundant=0,n_clusters_per_class=1,n_classes=3)
pl.scatter(X[:,0],X[:,1],c=Y)
pl.show()
