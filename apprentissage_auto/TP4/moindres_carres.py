####################################################
#          Apprentissage supervise TP 4            #
#  I - Regression lineaire par moindres carres     #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
import numpy as np

#--------------------------------------------------------------

def genMatrice(S):
    "Cree et retourne une matrice de taille nxd ou n est le nb d'elts de S et d la dimension de chaque element"

    if not S:
        raise Exception("Tentative de generer une matrice a partir des elements d'un ensemble vide")

    n=len(S)
    d=len(S[0][0])
    X = np.zeros((n,d))
    for i in range(0,n):
        for j in range(0,d):
            X[i][j]=S[i][0][j]

    return X

#--------------------------------------------------------------

def genY(S):
    "Cree et retourne un vecteur de dimension n pour n le nb d'elts de S, contenant l'ensemble des valeurs des S[i][1]"

    if not S:
        raise Exception("Tentative de generer une matrice a partir des elements d'un ensemble vide")

    n=len(S)
    y=np.empty(n)
    for i in range(0,n):
        y[i]=S[i][1]
        
    return y

#--------------------------------------------------------------

def regression(S):
    "Pour S une liste de donnees d'apprentissage et leur classe, calcule un vecteur de ponderation W par la methode des moindres carres"

    #Initialisation des matrices/vecteurs
    X = genMatrice(S)
    y = genY(S)

    #Rajouter le vecteur 1 a X sous la forme d'une n+1-eme ligne
    un=np.ones(len(y))
    X=np.c_[X,un]
    transX = X.transpose()

    #w=(Xt*X)(-1)*Xt*y
    X=np.dot(X,transX)
    print(X)
    try:
        X=np.linalg.inv(X)
    except np.linalg.LinAlgError:
        print("Matrice non inversible")
        pass
    else:
        tmp=np.multiply(transX,y)
        print(X)
        print(tmp)
        X=np.dot(X,tmp)
        return tmp

S=[[[1,2,3],2],[[4,5,6],7]]
test=np.array([[1,2,3],[4,5,6],[7,8,9]])
print(regression(S))
