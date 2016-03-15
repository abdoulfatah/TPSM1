# -*- coding: utf-8 -*-

####################################################
#          Apprentissage supervise TP 5            #
#           III - Perceptron à noyau               #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
from sklearn.cross_validation import train_test_split
import random
import perceptron_data as datas
import tp5utils as utils
import numpy as np
import math

#2.1) Calcul du noyau gaussien de 2 vecteurs
def noyauGaussien(x1,x2,sigma):
    y = np.zeros(x1.shape)
    y = x1-x2
    n = np.linalg.norm(y)
    res = math.exp(-(math.pow(n,2))/(math.pow(sigma,2)))
    return res

#2.2) Calcul du noyau polynomial de 2 vecteurs
def noyauPolynomial(x1,x2,k):
    y = np.dot(x1,x2)
    y += 1
    y = math.pow(y,k)
    return y

#3.1) Création et apprentissage d'un perceptron à noyau
def signe(y):
    "Retourne 1 si y>=0 et -1 sinon"
    ret = 1
    if y<0:
        ret = -1
    return ret

def learnKernelPerceptron(data,target,kernel,h):
    dataExt = np.matrix([np.append(d,1) for d in data])
    alpha = np.zeros(data.shape[0])
    n = data.shape[0]*data.shape[1]

    for c in range(0,n):
        for i in  range(0,data.shape[0]):
            pred = 0
            for j in range(0,data.shape[0]):
                pred += alpha[j]*target[j]*kernel(data[i],data[j],h)
            if signe(pred) != target[i]:
                alpha[i] += 1
    return alpha

#3.2) Prédiction de la classe d'un exemple avec un perceptron donnné
def predictKernelPerceptron(kp,x,kernel,h,data,target):
    pred = 0
    for j in range(0,data.shape[0]):
        pred += kp[j]*target[j]*kernel(x,data[j],h)
    return pred

#-------------------------------------------
data = np.random.random((3,3))
target = np.array([1,-1,1])
h=1
x=np.random.randint(1,10,3)

kp = learnKernelPerceptron(data,target,noyauGaussien,h)
pred = predictKernelPerceptron(kp,x,noyauGaussien,h,data,target)
train,test=train_test_split(datas.iris,test_size=0.3,random_state=random.seed())
print(train)
