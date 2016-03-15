# -*- coding: utf-8 -*-

####################################################
#          Apprentissage supervise TP 4            #
#           II-3 Regression lineaire avec          #
#        Scikit-learn et avec regularisation :     #
#                Ridge et Lasso                    #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
import random
import numpy as np
from sklearn.datasets import load_boston
from sklearn.linear_model import Lasso,Ridge,LinearRegression
from sklearn.cross_validation import train_test_split
from sklearn.metrics import mean_squared_error
from sklearn.grid_search import GridSearchCV

#----------------------Ridge et Lasso sur boston avec alpha=1.0----------------------------------------

def comparaison_ridge_lasso(X,Y):
    X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())
    clf_lasso = Lasso(selection='random', random_state=random.seed())
    clf_ridge = Ridge()
    clf_lasso.fit(X_train,Y_train)
    clf_ridge.fit(X_train,Y_train)
    score_lasso=clf_lasso.score(X_test,Y_test)
    score_ridge=clf_ridge.score(X_test,Y_test)
    print("Precision de Lasso={:3.2f}% \nPrecision de Ridge={:3.2f}%\n".format(score_lasso*100,score_ridge*100))
#Lasso semble etre globalement plus precis mais la difference est souvent assez faible

#----------------------Comparaison par rapport aux moindres carres-------------------------------------

def comparaison_moindres_carres(X,Y):
    X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())
    clf_lasso = Lasso(selection='random', random_state=random.seed())
    clf_ridge = Ridge()
    clf_reg_lin = LinearRegression(n_jobs=-1)
    clf_lasso.fit(X_train,Y_train)
    clf_ridge.fit(X_train,Y_train)
    clf_reg_lin.fit(X_train,Y_train)
    Y_lasso=clf_lasso.predict(X_test)
    Y_ridge=clf_ridge.predict(X_test)
    Y_reg_lin=clf_reg_lin.predict(X_test)
    err_lasso=mean_squared_error(Y_test,Y_lasso)
    err_ridge=mean_squared_error(Y_test,Y_ridge)
    err_reg_lin=mean_squared_error(Y_test,Y_reg_lin)
    print("Erreur de Lasso={:1.2f}\nErreur de Ridge={:1.2f}\nErreur de regression lineaire={:1.2f}\n".format(err_lasso,err_ridge,err_reg_lin))
#On remarque une erreur de prediction tres proche dans les 3 cas ; par ailleurs la regression lineaire a tendance a produire une valeur nettement plus faible que Lasso et environ egale a Ridge
    
#----------------------Choix d'un alpha optimal--------------------------------------------------------

def choix_alpha(X,Y):
    X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())
    alphas=np.logspace(-3,-1,20)
    for Model in [Ridge,Lasso]:
        gscv=GridSearchCV(Model(),dict(alpha=alphas),cv=5).fit(X,Y)
        print(Model.__name__,gscv.best_params_)
#Pour Lasso comme pour Ridge la valeur de alpha optimale semble être de 0.1, cela reste contant meme apres plusieurs essais

#-----------------Juste par curiosite : amelioration moyenne de la precision de -----------------------
#-----------------Lasso et Ridge pour alpha=0.1 par rapport a alpha=1 sur nb_tests iterations----------

def test_alpha_opti(X,Y,nb_tests):
    score_lasso=0
    score_ridge=0
    score_lasso_opti=0
    score_ridge_opti=0
    for i in range(0,nb_tests):
        X_train,X_test,Y_train,Y_test=train_test_split(X,Y,test_size=0.3,random_state=random.seed())
        clf_lasso = Lasso(selection='random', random_state=random.seed())
        clf_ridge = Ridge()
        clf_lasso.fit(X_train,Y_train)
        clf_ridge.fit(X_train,Y_train)
        score_lasso+=clf_lasso.score(X_test,Y_test)
        score_ridge+=clf_ridge.score(X_test,Y_test)
        clf_lasso_opti = Lasso(selection='random', random_state=random.seed(),alpha=0.1)
        clf_ridge_opti = Ridge(alpha=0.1)
        clf_lasso_opti.fit(X_train,Y_train)
        clf_ridge_opti.fit(X_train,Y_train)
        score_lasso_opti+=clf_lasso_opti.score(X_test,Y_test)
        score_ridge_opti+=clf_ridge_opti.score(X_test,Y_test)
    print("Lasso (opti - non-opti) : {:3.3f}%".format(100*(score_lasso_opti-score_lasso)/nb_tests))
    print("Ridge (opti - non-opti) : {:3.3f}%".format(100*(score_ridge_opti-score_ridge)/nb_tests))

#------------------------------------------------------------------------------------------------------

boston = load_boston()
X=boston.data
Y=boston.target
comparaison_ridge_lasso(X,Y)
comparaison_moindres_carres(X,Y)
choix_alpha(X,Y)
test_alpha_opti(X,Y,100)
