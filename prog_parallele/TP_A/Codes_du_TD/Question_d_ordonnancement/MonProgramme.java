// -*- coding: utf-8 -*-

class Thread1 implements Runnable{
    public void run(){
	for(int i = 1; i<=26;i++) System.out.print(i +" ");
    }
}
class Thread2 implements Runnable{
    public void run(){
	for(int i = 'a'; i<='z'; i++) System.out.print((char)i +" ");
    }
}
class MonProgramme {
    public static void main(String[] args) {
	Thread t1 = new Thread(new Thread1());
	Thread t2 = new Thread(new Thread2());
	t1.start();
	t2.start();
	try{ t1.join(); t2.join(); }
	catch(InterruptedException e){e.printStackTrace();}
	System.out.print("\n");
    }
}

