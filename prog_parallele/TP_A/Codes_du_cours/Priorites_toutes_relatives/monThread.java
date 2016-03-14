// -*- coding: utf-8 -*-

public class monThread extends Thread {
  public static void main(String[] args) {
    monThread p1 = new monThread();
    monThread p2 = new monThread();		
    p1.setPriority(MAX_PRIORITY);
    p2.setPriority(MIN_PRIORITY);	
    p1.start(); p2.start();
  }
  public void run() {
    for (int i = 1;i<=1000;i++)
      System.out.println(i + " " + getName());
  }
}

/*
morin.r@ens1:~/PP/Priorites$ cat /proc/cpuinfo | grep cpu
cpu family	: 15
cpu MHz		: 2499.998
cpu cores	: 1                              // Un seul coeur
cpuid level	: 5
morin.r@ens1:~/PP/Priorites$ javac monThread.java 
morin.r@ens1:~/PP/Priorites$ java monThread > resultat.txt
morin.r@ens1:~/PP/Priorites$ more resultat.txt
1 Thread-0
2 Thread-0
3 Thread-0
4 Thread-0
5 Thread-0
6 Thread-0
7 Thread-0
8 Thread-0
9 Thread-0
10 Thread-0
11 Thread-0
12 Thread-0
13 Thread-0
14 Thread-0
15 Thread-0
16 Thread-0
17 Thread-0
18 Thread-0
19 Thread-0
20 Thread-0
21 Thread-0
22 Thread-0
23 Thread-0
1 Thread-1
2 Thread-1
3 Thread-1
4 Thread-1
5 Thread-1
6 Thread-1
7 Thread-1
8 Thread-1
9 Thread-1
10 Thread-1
*/

