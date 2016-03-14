// -*- coding: utf-8 -*-

import java.awt.Color;
import java.util.ArrayList;

public class Mandelbrot implements Runnable{
    final static Color noir =  new Color(0, 0, 0);
    final static Color blanc =  new Color(255, 255, 255);
    final static double region = 2;
	final static double xc   = -.5 ;
    final static double yc   = 0 ;
    final static int nbThreads = 4;
    final static int tailleTotale = 3000;

	
	static volatile Picture image;
	
	private int taille,profMax, indice;
	
	public Mandelbrot(int t, int m, int i){
		taille = t;
		profMax = m;
		indice = i;
	}

    public static boolean mandelbrot(double a, double b, int max) {
        double x = 0;
		double y = 0;
		for (int t = 0; t < max; t++) {
            if (x*x + y*y > 4.0) return false;
            double nx = x*x - y*y + a;
			double ny = 2*x*y + b;
			x = nx;
			y = ny;
        }
        return true;
    }
    
    public void run(){
		double a = xc - region/2 + region*indice/nbThreads;
        double b;
        
		for (int i = 0; i < taille; i++) {
			b=yc - region/2;
            for (int j = 0; j < tailleTotale; j++) {
				// Le pixel (i,j) correspond au point (a,b)
				synchronized(this){
					if (mandelbrot(a, b, profMax)){
						System.out.println(i+indice*taille+" "+j);
						image.set(i+indice*taille, j, noir);	
					}
					else
						image.set(i+indice*taille, j, blanc); 
					// La fonction mandelbrot(a, b, max) determine si le point (a,b) est noir
				}
				b++;
            }
            a++;
        }
	}

    public static void main(String[] args)  throws Exception {

        image = new Picture(tailleTotale, tailleTotale);
        int max = 2000; 
		final long startTime = System.nanoTime();
		final long endTime;
		
		ArrayList<Thread> list = new ArrayList<>();
	
		Mandelbrot m;
		Thread t;
		for(int i=0 ; i<nbThreads ; i++){
			m = new Mandelbrot(tailleTotale/nbThreads,max,i);
			t = new Thread(m);
			list.add(t);
			t.start();
		}

		for(Thread thread : list) thread.join();

		endTime = System.nanoTime();
		final long duree = (endTime - startTime) / 1000000 ;
		System.out.println("Durée = " + (long) duree + " ms.");
        image.show();
	}
}


/* Execution sur un MacBook pro dualcore
> javac Mandelbrot.java
> java Mandelbrot
Duree = 15703 ms.
*/
