// -*- coding: utf-8 -*-

import java.lang.Math; 

public class Calcul_PiSurQuatre{
  public static void main(String[] args) {
      int nombreDeTirages = 100 ; // Le taux d'erreur devrait être < 0.1
      int tiragesDansLeDisque = 0 ;
      double x, y, resultat ;
      try { nombreDeTirages = Integer.parseInt(args[0]); } 
      catch (ArrayIndexOutOfBoundsException e) {
	  System.err.println 
	      ("Erreur: vous devez indiquer le nombre de tirages."); 
	  System.err.println(e.getMessage()); 
	  System.exit(1); 
      }
      catch(NumberFormatException e) { 
	  System.err.println 
	      ("Erreur: vous devez indiquer le nombre de tirages."); 
	  System.err.println(e.getMessage()); 
	  System.exit(1); 
      } 
      for (int i = 0; i < nombreDeTirages; i++) {
	  x = Math.random() ;
	  y = Math.random() ;
	  if (x * x + y * y <= 1) tiragesDansLeDisque++ ;
      }
      resultat = (double) tiragesDansLeDisque / nombreDeTirages ;
      System.out.println("Estimation de Pi/4: " + resultat) ;
      System.out.println("Taux d'erreur: " + Math.abs(resultat-Math.PI/4)/(Math.PI/4)) ;
  }
}

/*
> javac Calcul_PiSurQuatre.java
> java Calcul_PiSurQuatre 100
Estimation de Pi/4: 0.85
Taux d'erreur: 0.0822536130248883
> java Calcul_PiSurQuatre 10000
Estimation de Pi/4: 0.7859
Taux d'erreur: 6.389582073644488E-4
>
*/
