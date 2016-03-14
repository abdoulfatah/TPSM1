public class Mandelbrot{
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
}

public class Task implements Runnable{
	private int indice;
	
}


public class Main{
	public static int nbThreads = 4;
	public static int taillePixels = 3000;;
	public static double xmin = -1.5;
	public static double ymin = -1;
	public static double taille  = 2;
	
	public static void main(String[] args){
		for(int i=0 ; i<nbThreads ; i++){
			
		}
	}
}
