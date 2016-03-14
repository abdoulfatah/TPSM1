####################################################
#          Apprentissage supervise TP 3            #
#           II - Perceptron multi-classe           #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
import time
import random 
import numpy as np
import perceptron_data as datas
from pylab import rand,plot,show,norm
from sklearn.cross_validation import train_test_split

#--------------------------------------------------------------

def argmax(W,x):
    "Calcule le produit scalaire de x par chaque element de W, et retourne l'indice ayant donne le resultat max"
    max=-1
    ret=-1
    for i in range (0,len(W)):
       y=np.dot(W[i],x)
       if y>max:
           max=y
           ret=i
    return ret

#--------------------------------------------------------------

def association(S,m):
    "Remplit et retourne un tableau de strings ou la case d'indice i contient le nom de la i-eme classe. Permet d'etablir une association entre des classes de nom quelconque et des int"

    if m==0:
        raise Exception("Associations : l'argument m==0 (nombre de classes a trouver) n'est pas valide")
    
    trouvees=0
    asso=[]
    for i in range(0,len(S)):
        if not S[i][1] in asso:
            asso.append(S[i][1])
            trouvees+=1
        if trouvees==m:
            break
    if trouvees<m:
        raise Exception("Associations : il n'y a pas autant de classes qu'attendu")
    if trouvees>m:
        raise Exception("Ceci n'est pas cense arriver... plus de classes trouvees que prevu")
    return asso

#--------------------------------------------------------------

def ajout(w,x):
    "Ajoute la valeur de chaque element de x a chaque element de w, et retourne le resultat"

    if len(w)!=len(x):
        raise Exception("Tentative d'ajouter un a un les elements de listes de tailles differentes")

    for i in range(0,len(w)):
        w[i] = w[i]+x[i]

    return w

#--------------------------------------------------------------

def retrait(w,x):
    "Soustrait la valeur de chaque element de x a celle de chaque element de w, et retourne le resultat"

    if len(w)!=len(x):
        raise Exception("Tentative de soustraire  un a un les elements de listes de tailles differentes")

    for i in range(0,len(w)):
        w[i] = w[i]-x[i]

    return w

#--------------------------------------------------------------

def perceptron(S,N,m,classes):
    "S : liste de donnees d'apprentissage. N : nombre d'iterations de l'algorithme. m : nombre de classes possibles pour les elements de S. Retourne m vecteurs de ponderation, un pour chaque classe"

    #Cas d'erreur
    if not S:
        raise Exception("Tentative de classer un ensemble vide d'exemples !")
    
    #Initialisation des vecteurs Wlk
    #W est une matrice ou chaque ligne est un des vecteurs, la i-eme ligne correspondant a la i-eme classe telle que definie par la fonction "association"
    W = np.zeros((m,len(S[0][0])))
        
    for i in range (0,N):
        for s in S:
            pred = argmax(W,s[0])
            reelle = classes.index(s[1])
            if pred != reelle:
                W[reelle] = ajout(W[reelle],s[0])
                W[pred] = retrait(W[pred],s[0])

    return W

#--------------------------------------------------------------

def prediction(W,S,classes,afficher):
    err=0
    for s in S:
        pred=argmax(W,s[0])
        if classes[pred] != s[1]:
            err+=1
            if afficher:
                print("Exemple {} : predit comme {} au lieu de {}.".format(s[0],classes[pred],s[1]))
    return err

#--------------------------------------------------------------



#Tableau regroupant l'ensemble des classes possibles w.r.t. l'ensemble S
#Une classe est arbitrairement definie comme la 1ere et se trouve dans la case 0, etc
classes = association(datas.iris,3)

#Separation du jeu de donnees iris en un ensemble d'apprentissage (70%) et de test (30%)
"""train,test=train_test_split(datas.iris,test_size=0.3,random_state=random.seed())
W=perceptron(train,10,len(classes),classes)
err=prediction(W,test,classes,True)#Remplacer True par False pour ne pas afficher le detail des exemples mal classes
p=err/len(test)
print("Echantillon de test : {0}/{1} erreurs ({2:3.2f}%)".format(err,len(test),p*100))"""

#Pour une plus grande precision, on repete l'operation de test 1000 fois d'affilee
#L'execution se fait en 8.5s sur un CPU Intel i7 ; si cela est trop long, la version commentee (lignes 121 a 125) effectuera exactement le meme traitement, mais une seule fois
erreurGlobale=0
start_time = time.time()
for i in range (0,1000):
    train,test=train_test_split(datas.iris,test_size=0.3,random_state=random.seed())
    W=perceptron(train,10,len(classes),classes)
    err=prediction(W,test,classes,False)#Remplacer False par True pour afficher le detail des exemples mal classes
    p=err/len(test)
    erreurGlobale=(erreurGlobale+p)/2
print("Erreur globale apres 1000 tests independants : {:3.2f}%".format(erreurGlobale*100))
print("---{:3.3f} secondes---".format(time.time()-start_time))
