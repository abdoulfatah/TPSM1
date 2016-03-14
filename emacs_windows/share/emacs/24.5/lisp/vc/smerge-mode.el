;;; smerge-mode.el --- Minor mode to resolve diff3 conflicts -*- lexical-binding: t -*-

;; Copyright (C) 1999-2015 Free Software Foundation, Inc.

;; Author: Stefan Monnier <monnier@iro.umontreal.ca>
;; Keywords: vc, tools, revision control, merge, diff3, cvs, conflict

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Provides a lightweight alternative to emerge/ediff.
;; To use it, simply add to your .emacs the following lines:
;;
;;   (autoload 'smerge-mode "smerge-mode" nil t)
;;
;; you can even have it turned on automatically with the following
;; piece of code in your .emacs:
;;
;;   (defun sm-try-smerge ()
;;     (save-excursion
;;   	 (goto-char (point-min))
;;   	 (when (re-search-forward "^<<<<<<< " nil t)
;;   	   (smerge-mode 1))))
;;   (add-hook 'find-file-hook 'sm-try-smerge t)

;;; Todo:

;; - if requested, ask the user whether he wants to call ediff right away

;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'diff-mode)                    ;For diff-auto-refine-mode.
(require 'newcomment)

;;; The real definition comes later.
(defvar smerge-mode)

(defgroup smerge ()
  "Minor mode to highlight and resolve diff3 conflicts."
  :group 'tools
  :prefix "smerge-")

(defcustom smerge-diff-buffer-name "*vc-diff*"
  "Buffer name to use for displaying diffs."
  :type '(choice
	  (const "*vc-diff*")
	  (const "*cvs-diff*")
	  (const "*smerge-diff*")
	  string))

(defcustom smerge-diff-switches
  (append '("-d" "-b")
	  (if (listp diff-switches) diff-switches (list diff-switches)))
  "A list of strings specifying switches to be passed to diff.
Used in `smerge-diff-base-mine' and related functions."
  :type '(repeat string))

(defcustom smerge-auto-leave t
  "Non-nil means to leave `smerge-mode' when the last conflict is resolved."
  :type 'boolean)

(defface smerge-mine
  '((((class color) (min-colors 88) (background light))
     :background "#ffdddd")
    (((class color) (min-colors 88) (background dark))
     :background "#553333")
    (((class color))
     :foreground "red"))
  "Face for your code.")
(define-obsolete-face-alias 'smerge-mine-face 'smerge-mine "22.1")
(defvar smerge-mine-face 'smerge-mine)

(defface smerge-other
  '((((class color) (min-colors 88) (background light))
     :background "#ddffdd")
    (((class color) (min-colors 88) (background dark))
     :background "#335533")
    (((class color))
     :foreground "green"))
  "Face for the other code.")
(define-obsolete-face-alias 'smerge-other-face 'smerge-other "22.1")
(defvar smerge-other-face 'smerge-other)

(defface smerge-base
  '((((class color) (min-colors 88) (background light))
     :background "#ffffaa")
    (((class color) (min-colors 88) (background dark))
     :background "#888833")
    (((class color))
     :foreground "yellow"))
  "Face for the base code.")
(define-obsolete-face-alias 'smerge-base-face 'smerge-base "22.1")
(defvar smerge-base-face 'smerge-base)

(defface smerge-markers
  '((((background light))
     (:background "grey85"))
    (((background dark))
     (:background "grey30")))
  "Face for the conflict markers.")
(define-obsolete-face-alias 'smerge-markers-face 'smerge-markers "22.1")
(defvar smerge-markers-face 'smerge-markers)

(defface smerge-refined-changed
  '((t nil))
  "Face used for char-based changes shown by `smerge-refine'.")
(define-obsolete-face-alias 'smerge-refined-change 'smerge-refined-changed "24.5")

(defface smerge-refined-removed
  '((default
     :inherit smex�6%{���,ȦWzp�e(�` �H%(,lU{A.�n�r�!rmx����/ã$<;8b1{`h'r4nTAhad�m9 0 �F8ej�b/w`e3AB"�YF� H�)h)>�g��z3K�Lm3i1-m,b-rC(C2w����j a�Rl�~/f�k�{))`�Q��zk��-ryvL`j=`3Z4��
0� ")PaG.ROO�u��!d�l,�&)�2��!�^:�caa�&3(<���g�1cdA�eo|�|s>Vo�S��+�%`��a"�G1x5�k
d&kzJ0��lavm��an� 2) �ogmwp9rm}�g$	vE%Hn|$-��qo�� ���euf��@� ��t�>).9%I%fe2�e��g	ymeAs ���jd.�x8�*;K�z�^o�O9�d-L�:em��3�h�"zbaR�#f0nh0`����y�
0 j���j��YAoT�~ �gf1j�qb!� b��!|�:UC�NH�(�(LiD�o'L��8h(��aa+F�G4N�hd �i+{�!	
x�\gc�vG��')���2�X�2)1,*���]9F|m2jv-�}�Ao |!!Z C"�asm�nwLd!v�!�T@Al+1SQrckd`� zF�n/
k���Bu�c|a�eN.e?`hj��s�i/� :9/3#�")ifL�X=�i`e�dg��tr�`jgg�za�f-ye�
`j�2�"�*=kndRWf9vs�5"0(��L3.��%ph�;g�=B
Nwi �r�"���!i�-�qM4�s/\Rq,Z+�4���shb,�$g�f�Kqe�,�9B`!f�4J:`�!ryc$m��`�/�y�T�.!|h"c8(^ ׷�rrg�NUC�)�dhogkL,$)�(���. U)a��!jI5@l	&#B0pdL2g%enBOa�5Eu`f68�)#@��43&b(�sm@-pol#�JQ�vIpqL�qu%�   �8�)�$�"GBw5-ve�Yv5"r�A��*����"(.q{CT��,Bq0e#[Bvt&�/�Dc`p�"K" G  ���Cp�`'R1 }�&qm���
��Vrx�a �`(�H' ,`U{A/�n�"�/2{q��Э%ɦ&-c0cD5hl%p $Ah#d�(2rMrt(_vN8d"�f(saeV5I@#�F�QI?k|iw�'��h1
�L-#i1mm,`-~S(C"w.>��g g�Yn�?/o�k�-hFb�Q��h+Ү�(bqvE Ca=dsHfe� 2�A2mQu
G.A�9�� d�lo}v0���!�^�cka�$7)4���r�1UE)�|oj�,b\vm�s� &�g ��i#�G1m5�n$"cjO}��lC-v��:|yA� 7(gl
�kelgz;ru<�t A @%PCz  �*Po�� ��tcwn�� �@��t�>	!"	&Ng �O��/
Y)as(�N��pid.#�zM:�":K�*�c�N{�E)�:em��-�m+M+zgf\�`lv ezt`����u�i14j���j؈�YEbF�>`�mn1j�=�rG!� f�>T!}�.UC6MI	�,�aXi�l 
��MxhL.��aasL�R>O�in �a+s�+	EJt�\v!�eE��'-��c��sil1n+�9-M1Gdm6hri�w�A-b|&e_`On�csl�nwLd!v�	#�U@K-kSS2+
 `�`nf�	e7�g���Bs�(la�%*gOd;hn�c�{%�Ki>#!!�")afL�H=`xa|�hs��ur�blgv�8(�voyt�/dk�t�'�jwk.`	B6s�%3p(��\w	l��gtr�;e�3F	NchM#ws�#��	�9H�<ey
4�h?]@rnZ-�u��skbn� c�h��Hp$�0�sFaag�uH}a�-bqc$h��h�"�y�T�.	�!|i%"yhRtŷ�1ZC�NTJ�(�`z+okll'i� ����g !`e�!bA3@( "b8xdV:gmenIL
)�	6Eq`u5x�owD��1|w&b �wm-tnd!�@S�0Yyu\E�%m%�%%e�p�+�$�"F0,dw��R5&p�O愯܋��'��EEsSE� 0 s"JAtt"�'�Ecgq�fKjpE!`���0C� 6C1}�> k���(��~Z�a$�b�UB�h<q9A/w�g�/�3r8����!��/$s<b1th/p�g_Mcee�* 0 ~:L �`([!kU1AA&�W�EZ�miw�v��l5
�Dl0i1Om,`&6C(8w����!s��Uj�>/g�k�q�)�b�Q��lm��-byvEaq=T
#H"$��	4�H�ISaG�AO�[���d�l�*v!�?��+�:�ghq�&U3i$��{�g�q!dy�aon�lv<F�r�!/�'(А`"�V1i5�n "cjF0��lCawe��hmbK� ($> �{m~gp9re|�c4PrE$T)x0)�L*�� ���a1b��Z�SA��t�>,/9BI7fg �m��gA=ieEs �[Ÿ:hdnq�ZM~�B<I�j�S^c�u�u)L�:$��!�z)]Kzg`�imv"e(p����s�Y2$c���j�!%YAOT�~r�`f=k�w�aO%�%g��D08�*UC6�$�,JjT�m"��]rhO.��a! @�R�O�if �i{�3EMJx�^o!�eE��')�ًk�\�2k|qv*�s-]3G,o7lr-�u�A$:x%eZ Ck�erh�juH`%t�-�^@J);�Q:ckdh�`"W�s'/���B{�!lQ�%
&;`hh��c�i'�@?{'+a�&-E"N�Fw	`i`m�ls��e�`l##�8 �voyt�"hn�p�c�b7*nd@b9rr�%&|x��\sl��%pj�?e�3V
Nab 62�2���)i�-rqM5�m/[ r,Z�4���T)cn�c�d��\xe� 2�urca�uN=`�c`Yc(mZ��`�"�;�T��%|n&2yjRrŷ�qzf�F_B�i�ehooclne{�!����oD(aa� ` @8"#rE0xtL1seeoKHGc
�5U`$08�+GL��}w'n0�wx%pod3�@��DruLI�e-%� %`�0�)�,�"F 54Mfg�v9&p�A��&����e:.d{S��$Vp4`#�v| ����chp�!�baU!r��SxC�g'A1 }�* 9���(��~|�a �`�YJ�h,e]A+�.�3�%rk
1����'æ,#�bL5p`#p$$UEigd�o0rLr~(Vv8ld�c/�amU5QJ��F�H�yksw�&��l1O�@�!ky%=,`0( K"W}>�r%s��Tj�w/g�k�=)iBb�W�n)���9bq~T b=p c]ve��2�H�m[eG�AOO�����f��*& �;��)�^:�cia�&u?k,��{�s�Yd0�dO���f~Vo���/�daԙb���1l5�ntbkjGxѮ(!v%��elP�@ifm
�ka~vp;z%}�f&HaA$ wx4h�nqz�� ��ta3c��h� ��}�>-%=cI%bg �-Ņ' 8)aS(�K��(mdou�yNx�g8��h�S^m�Ou�t<�rle��)�J�	CzntT�`lf nx0b³��y�a1 s저k�$YMeV�~$�of5+�2a!�af�6 8�*]C�\�2�%N`�n�L��zh](��eqrD�T0^�il �a_s�!I]CJu�\$)�tA��/o���v��;k>Y.+���]:Glm2jv`�U�A&`x%eZ`G/�arl�juHp%~� ;�UHP(+Qvi b�`ff� h7�#���Bu�)~a�mN.&`:hJ��e�x%�Kl:)sie�f-mbL�h=	hx >�lq��Es�b?jen�|h�v(ze�3n~���3�"4*nd��1rr�4�x��L��,��gpp�?e�?VNmeZ'w;�"���=`�)ry]4�b�YBs,z;�����Pjc��&'�`��Nq$� �0bi)n�uNsm�cpQc$zN��@�.�9�^�/	A%|'r|kZ ŷ�1rg�FWC�`�dh/goln,i�0���& 9 a�pfA=Dl$#cE0ptD0gmebL�
! �4 3`w5x�ogB��5=w'j �smP%tf 1�J�0 0q@�em$�%%e�x�+�&�"FBu0ong�]2"p�A��;����e:(LasCT圤Fq.g$
vr"�&�Ek|p�aJj Wab���UxÕf/B5 |�2%}���,��rp�ar�d0�UIe`<iU{A.�g�"�%sx��Ь!��$.k<bT1(H!p�dU`gd�l8v 8
�:mn�`(�ai1Q[��YF�EZ?i{iw�g��m7O�L )K-m,bo~C; 2�>��o!e�z�6/N�*�<-8`�W��j]ү�,byL`Gc=ds\*u��6�	"mPaG*_�����f�L\(.(�^��#�:�gbC�s7(.��{�g�qauI�toh�}v>v��2�%h��X+�Ni�ndbCjCt��lC�vg��tlEC�`u(&^�-}ux;r-� $AfD%P z-e�nq/��`��tCe5s��`�@��\�>(=eI$fg �o��g }ieAs1��� od.c�zLx�f8I�(�SeÍ�e,�2l��!�n!IczstX�amf2dx|`����u�(1$s���{�
A`D�~f�mF7*�0`K'�%C�6 8�:C?MH	�$�(XaE�n!L��thN.��mekN�E�O�kl(�ao��)DMGJp�do�tE��'k��{�^�v)>;�;=];$M3,va�u�Ade#1Z8K*�c2L�nmLd!r�3�UHJm{1Q~f(bh�`�G�e?�+���R=�ina�eN.eMl:h���u�o/�Sm?{'a!�e-`fL�Bu
hh)~�`C��dv�bj!�z �v8$�+`~�v�c�r?+~dB_f1vs�%"0(��L3n��u|p�;g�3BNij46z�#���qH�)zy4�r>_Rpnz/�=���Xhan�&n�d��Mqt��,�tbh!g�uK8Y�cbzc8k��`�+�y�P��Q%|h"#|hVrǗ�Rrc�FVC���eikggll.{�0����f D  l� `Dd" "sApp�L1geen	  �	uPs`v0:�o#VD��143'b"�smB54g,!�@S�vHquLQ�g9$�!�`�t��+�.�"Fu=_lu��R5"p�Q��*܉��e.(azC��$Rq-a%ZCt|$�'�EKdp� J*3E$`���CxB�iBp |�>g-���,��Wz~��h�i)�K� , 9	.�&�r�-rmp����/ç%6c0cL5{dl-r�m^Mbed�l0v :(r8d(�`(n )U5AH&�YV�@Ykms?�f��m5K�H)3iuco, o6C)0w����!u��Pl�>/g�k�p�)�b�U�nm���,fq6M Bq=dsMwd��<�S)PaG> O�uڧ%l�l\m)�;����~�'qC�}3z$��{�g�9qd(�moj�,b^Fo�s�%.�e`��h*��y3�o
p�cJB0��lCeve��i~e	� 0(wm �oem�p;z-}�f&HaA$x (�lp*��a��tgsb��`�@��}�?,.9nM$"e �e��oP�ieQs����h<`�o�xM��b8˭h�^i��f<�zd-��)�h!	*zglT�amv g(|b����u�h5$k찁K�-YEgL�~l�bf1+�0`'�%g�v0|�*]C6LI	�0�mZ`�m$J��Mth(��imaT�@<N�kh*�iow�3I	
p�,i�dA��/)��v�X�wa,1,+�;-M9Gto2,vl�w�A$(|!u[hGg�e2i�J,H)t���UHRmo1SV0*i`p� ff� q/�/���By�cla�mN.g;h;hh��c�l%�C�>)sag��-a"L�Twhhag�la��dr�`?lan�8m	�fh9d�'nn�v�3�"=j>`	b0vr�-%pi��Lwn��pr�;%�BNef]$6s�2���%H�-np\5�h,Bylz?�=��vial�&r�`��Iqe��$�yfj)g�tI0h�ars#4n��i�
�9�Z��5|m$"|jRt׷�qrs�FSC�)�dkk-cll$)�(����o (cd�pnS@d$"sErpdV;#uenL
  �uD}`g5z�okON��5uw'j �w(J-0�h!�BQ�tLxqI�#!$�$%d�t�)�,�"}1|fm�Yv5"r�I܋��a��M%rCEᜬ@q f)z �'�Ek`q�eJgeEcb���Gx�i@1}�6 )���(��Urx�at�e �UJgh,t{I.v�o�v�7{y0��Ь'ì$$k<g1; `;r wUEbge�l1b~(V�N8e �e,kac?AX��YO�AJ�)zkw�v��n1K�@�)i1gm,`n~C* w;?��f u��Sl�w/n�*�q)kFb�W��h)��-rqvTaVi�  #Hse��4�I#mRa
G/BOM�s�� d�,̨t �:����^��)�$13($��y�v�9ad�uox�}b<fi��2"�%h��s"�N1m1�o trkzG<��h!^g��}mnA�h\x, �cmez1zm=�t(	$E%Dsx)(�1*��a��tGgus��`�@��u�?)4=b	%ne2�-��' x)eEs(�J�� (`ne� yN|�"8K�*�a�M9�f-D�:d��%�z;bzrwP�`lv ezt`����y�)2$c��j�)�IhD�zn�`f>k�~qW#�df��D08�*C6	�2�mZcE�m!L��O~jN,��e)
@�@:N�hl �az�!\IA
t�\e!�eA��'{���c�Z�s)m9$�p-M8Glm3,va��A$m8!!ZK+�asi�jld!t�	)�YHI9;1SSrsx`b�h"v�`?/���Ru�klq�u+g;M`;h��m�>���?+/!)�-abL�H}`(1$�p!��Er�`hen�:a�f(yl�3h;�0�"�*u*~d��1rs�	4�(��L{�,�� �;%�9FNst"wr�2���qh�)nq5�r>UBp,z�t��Y(A� "�`��Jqd���$�0ri!g�tH=a�chyc4i��i��y�\�4	;|o!c}(Z`׷�0rf�FB�(�aik%olN&k� ���o9b��an�D�d�$ 'r0pdN0#eenNLKc �4Ay`e2z�}kL��}7&b(�s}5pnh�H��suX�!'$� 2 �8�)�,�"F}1|fm�R5"p�A�������)
	 :SD��$ p$`(JBuv �.�Eciq� KclGa ���x�
@0 x�&g}���)آrr��4����YK 9*�w�r�-r}
p����%ã$6k<g1{t`3p4-RUbgd�* 8 r8m`�c(k`eW?II&�YO� H�yki?�f��i1�H�	iumm<`.vC)K.w����b-a��	l�v/o�*�q-z`�U�lm��)by]1j=t3\je��2�A2iZa
G.COM�u��%d�l<kl)�s���!�^~�o c�.w7),���r�9qe�ao���b?Fy���#�e`А`��F1i7�o  vcrG=��hKev%��nmf	�(iFd�{)mw:9re|�a" bE%Pf|=a�l1/�� ��vWe1c��B�A��|�>,%9	$"e �'��oB�iaEs(�K��"jdnw�zz�n>I�j�Se�M1�d-D�r$d��#�m+Mcznb�
lf"fz|`ҵ��w�)14z��k� %YE`� �cF5j�}pK!�es��L!x�.UC�NH�(�lZ`T�m$��~hM*��aa(@�T8O�jb*�a+{�1MYAJ|�^em�eA��'���z�\�skn.�0-M0�,o2hr �w�Alt<%a^ K*�a2h�JlHl%p�-�R@A-o1ST=#kfb�`vg� `/+���B3�i^a�-N/g{]l:jh��a�|-�`?kkk!�a)afN�H?
�) $�h���dw�`hvg�|x	�v{ym�
`:�0�"�"<*.` b9vr�-&xh��L
n��%|*�;%�1BNa` 62�*���-h�/ixN]4�m<_Rylz/�<���P(`,� #�`��Hp$�� �}fbag�uLm�oprc$mL��i�'�y�P�-E)|i!2|(R Ŷ�Pzf�F��`�dioecl,-)� ���&1 d�1~K@` &rAXttT8g%ejNFNk�	6 1`408�m+L��u3'n"�{m70�h#�@Q��	0q@�!y$�$'`�p�)�.�"00,$%�21"p�A��"���� 8iEt:SD�$F0/f Z@up"�.�Dkop�"J" E  ���8Ý
.@1|�2${���,��Ur~�el�t(�TIgh 9I.�f�"�)rhq����3ï&$#4gN5 h/r�n^U`ud�m;Lrt"z8d"�g,�!cT3IB��YG�EI?k}kw�g��nJ�@�kqem,b$xS(A,m>��k$a��Rn�/f�j�0)zF`�U�h)��-fyvDaF`=`#Zgu��4�K"	RaW�AO�����5l�,onl9�s��)�^{�g A�4s;{4��{�b�yedq�toh�lg<fi�S�0&�ea��a"�G3i7�ndfcrO0��lCawe��Y~GI�`zhfl�'���;ze}�v P&E%b~%-�lp~��p��tSeqg�� � ��|�?-#9o	&ne2�e��|maAs �O��`=0.s�{[8�"=��x�a�;�e-D�z,��%�h)IjzghT� l& ohx`����{�y5 r���k�*-YMe��"�nf3k�ra'�er�vL |�:UC?MH	�(�)JJ�m&L��M|jO,��emkV�E:_�zb �aow�!LM
p�ve�gG��/���{�Z�rc,qn*�3�-M2Gdm7jvd�_�A. 8 q_hOv�esl�J$�p!p�'�UH@)/SUrgi "�hff�t/
"���B�clq��^e;]d;hn��m�}'�Sa>igs!��)l"L�Xu`xit�t���Ur�`n f�~c��{$�;`n�r�f�r4kntSWb0vr�4����\{
n��gx �?g�=Nu`K!v2�"���!h�:ypK\4�h�Qp,Z;�}���Vzal� w�d�H�e�.�{fcif�tL8��ixqc�nN��p�"�{�T�-A!|i#c8hVdŶ�vrB�K����X�-o|,,=� ����g  `e�anC�Dl 'cEqpdT8g�egKDk�tE1`g6z�icVJ��1=3&j(�{mH5tf !�@Q�Ipq\E�e!%�!$d�p�)��"GFv<mfu�2&p�A��#܉��m)nM 2C�,Dq2t!J@4r �'�Dksq�`JcsEd`��SpC�o7S1 x�.pm���-��Urp�u`�l9�QAmh,d9;�f�s�/wh
y����/ë-.c0cN1{lh)r4-]L`ae�i4{Ob<(_~N:dh�`.o`-V=I@3�Yǚ H?;hcw�'��j5N�Lm!iue-<`e0C9C$w(?��b%q��Th�/f�j�s)(Fb�S�|{��-rqvDaS`=dH"5��0�P#mQqG:ROM�s�� f�l,mn �7��#�^?�orc�,y;k,���v�ygdh�loj�,bf}�3�!.�g`��k"�F1i1�kdrKbB0��hCmg��tmxA�`rite�kelfp3re|� &fE$Ti~)e�(rk��!��Vaug��j�A��u�>/9eI%bg �g��/I}ius0�Nĸ
( .Q�x]8�f8I�z�Q^g��E(N�zte��!�m+	szfeR�iov2e*0B�����c2 k���k� %IJ�:`�dn1j�0aG'�%g�v �*C7MH	� �!\bU�o&��_~h_,��imaN�@8O�in �aKw�!PMJx�,c�uC��k��k��;+,1$*�0=];GlO(ri�w�Aet< e^`W"�erm�J,Ll%p���VHI(+�SUurkd(�`bf�o/n���B;�(la��+%;[l;jl��e�-'�S`?kw))�!)`"L�J}	h) %�d!��uS��l#+�x%��;�,�7`o�r�f�b.`b02r�50<i��\3
l��gt(�;笵F	Nui63�;��	�qh�,lpO\5�l-YZ:)�4��Q:C��$c�d��^qt�	 �}r`ao�uO8��ijsc8h��p�*�{�ܴ-	)\i "8(ZtϷ�rrg�F_B��AI+-c|n'k�	���f�8`a�ptP0D$ 'bxxdL8ceEv	
	 �sAu`f7��}{H��1us&b �{m -4g !�BQ�zMxuLL�'�   �|��;�$�"C}5~fe�Yv=6p�U��'�ݢ�)(( r[�D4e KBur$�/�DK`p� J"(Ee`���xB�b.A1 }�*!)����(��rT�qd�s �]@gh,d\yA>v�v�r�)~|0��Ь5Ũ$-s0gT1;``%p4wTAkce�m4w0 r:ev�e-zaeV9IJ�F� Hi|!>�f��h1O�@e!{qm-,`gzS)A wm?��o-e��Rl�~/n�j�9	)`�Q��nm���-fqvEpCh=ds_ct��<�R#mYaG+BO�1��$d�,-)	�s���#�z�oks�,q3k4��9�r�qee �poh�|w}fo�3� /�%a��`*�O1l5�op�kjJ9��lCive��n| A�`uid-�omnd81re|�s(	!A%�z$e�lr*��a��taqr��(�Q��u�?-.=`I4bm �g��'I8iaEs ���h;d.'�xI~�c<I�:�a�u�d)F�2tl��#�n#IczbwX�hlf fx|b����q�q2 o��k� 7IBT�:"�nf1k�sa%�af�vL |�*US7MI�,�dJh�l!N��M|jL,��c	 @�D4^�hh(�ior�)	
p�$!�tE��'}���c�X�wa-qt*�q-M:$m2(2 �}�Ame8 !ZpOg�a2m�no�)p� -�RHJ(+1P0"(  � "f� `'"���Rw�a~a�e^.f{Od:hh��o�n%�(;)+im�e-efL�Phxio�h!��dR�`?h "�~a�6(8u�'`o�0�g�r/n`AWb92r� -&|x��\w	l��e0(�;'�1Na` 62�"���!(�(bqN\5�m?UBslz)�u���xxcl�4+�x��Hxe�$�tf`io�uO~i�)0Z# h��`�.�y�R�,Q/|n "}kVfͷ�qrb�UK�(�ez�ecl,,i�!����   `� ` 0@   "b0pdF1geerFBb�uDw`$38�yoON��1<3&j(�w-@-t/`#�HQ�~L9qH�#!$�  a�tT�)�$�"FE=0~nu�v1"p�Q�*܉��d)hEtsKT��,F0-s%
A4t �&�Dchp�dKfeEb`���G0C�b&A1y�" )���,٢Urr�qb�J �@-p,tU9I;w�.�"�3rk9����!͠&-+8B1; h'r-SIase�j9 0 vN8l,�e:raoT3QJ��F�DJ�)j!6�&��|5K�@�	iqom,`-|C*	*w(>���(w��Uh�~/f�k�)x`�Q��h)���(bq6L`Gy= kOje��0� "MPaW/_�۸�4l�,,\\(�2���+�^;�O)S�9;i&��]�c�Y!U0�yOj�|c\V)��4�g ܑY+�^1|�/ kJB0��(!v%��YnEC�hz(&U
�{a���1ru}�g( &E% x%a�lr:��p��ta1b�� � ��t�>( 9(I5fg �-�w�|iaEs(�O��p= .o�y|�f=��z�Q^o�9�d(�:,��!�l)	"zjnP� of v(pbе�y�a4 j���k�*.YMe��(�Jf9*�0`#� b�6 8�>US6LI� �+HhU�n!N��M<j],��c!(L�T:O�{d"�ior�)		
p�$!�dA��')���{��2!,1$*�0�=]2Flm3lve�W�A$tx!qZhS"�ash�j$�`%p�-�RPP)oSU"(  � "f� `'"���B1� la��N
%;l:jl��s�,'�Cm:yo!c�-dfL�X=hi f�`���Uw�b?n "�8 �;8$�"`*�0�"�"4*.` b02s� 4����L?,��%0(�;'�1Na` 62�"���e(�,ixM4�h�@q,Z9�=���Tybl� n�j��H�$��  �0b`!f�4H8��ipq#�j��h�&�9�P�'%|l 29
R Ŷ�0rb�B����X�%cl,$)� ���f   `�prI�Dt$'cAqpd\9c�ejBFb�49`&08�)#@��143&b �s( %0" !�@�� 0qQ�as$�!&e�8��)�$�" 00,$%�21"p�I��3܉��n,lMdsCU��$Tq.e)4p �&�Dc`p� J" E  ���EpC�n'S1 y�>$+����(��rp�a �` �H% , 9*w�.�g�!sx9ă��)ͦ.$#0b1; `!p $A`!d�(02 0 r8lt�d(jaaT9IA&�O� Y?h!6�&��h1
�@ !i1%-, $0(  w(>�j-!��Rh�w/f�+�u-jFb�Q�|k��<RynE i=  #L"$�� 0� ")PaG* �1�� d�,,($ �2��!�^~�/pc�.u?j$��;�c�qaeq�pon�,v=f)�3�!+�' А`"�F1h1�*  "cbO4��hCe~e�� l � 0($$ �kg~wp3r-|�f$ 1A$  x  �,0*�� ��ta1b�� � ��t�?))9 I%be �/��' 8)as �
��jztos�xI~�"<I�h�a�1�d(�2$$��!�h1	"zb{V�c}& eht�����u�p6(b���j� $A`�zf�hf1*�psC!�dg�vD0|�.]C7		� � H`�l ��zJ_���mqAR�T>^�J` �a+r�!Q	
x�\te�gE��7}���*��2!,1&*�0-M0$m3j2`�u�A$o| eZhKn�c3h�jd!p�!�P@@h+1P0"("(�`"V� o7k���Ru�)LA�%.$;	`:hh��c�(%��:ioqi�f)a"N�@hipl�ds��dv�`le.�xa�6)8,�/fk�4�c�b4+.`
b02r� % 0(��L3��0 �;e�7F
Nsk��r�#���9H�	qx\5�i- p,:)�4���p(cl�/�t�Myt��&�u�j!f�tMvH�! p# h��`�"�{�R��
E-|i&s9(N ׶�QrC�NUB�i�ei+cl,$)� ���& (`m�pt >D<$&r|tL13%e^Nk �vT}`t8�)#H��143&j �s( %4�h��@S�|U2qA�gc%� &d�|\�9�.�"GEu0,fw�21"p�[��#܉�� (( 2C��$ 0"u-�4~4�.�Ekhp� J"(E  ���8B�b7A0 }�*fm���-٢rp�a �` �@% ,y^{A:v�&�>�?>~0����-ţ$&{<b1; `!p $A`!d�j5vM |(^v8ld�a.g!)9II#�F�DKk{q6�g��o5K�@m){u--,bf|C(K$z?��{,g��[h�vn�*�\-(B`�U��|+���bqvDqF`=dsOg%��>�R#-YeW:AOM�s��%d�l,(f!�2��)�:�Gxq�$s7(4��9�g�q!ui�hon�|b=fk�s�%.�g ��a"�W1i7�JD&kBNt��(!~g��emeI�`�yeo
�k!ldx1r%<�c.IeE$Tsx()�
0*�� ��taso��@� ��t�>((=oM'.g �g��gC9	as �
��hld.)�x��"8Y�h�Qa�N9�d(�2$$��!�h!	"zbhR�`}&"ohp`�����i5,v���k�#,EoV�zr�`f>j�ta!� b�6 8�.UC>H	� �`NiD�m!��0h,��a)cN�G<O�ib �iks�#		
p�$!�dA��/m��v�^�ra~q$;�-M0$m2(2(�u�A-ex#uZpKo�C2h�j$`!p� !�SHImo1SUunxdr�`bg�r'	*���B1� la�%*e{I`:hh��m�m/�S):)#!!� )`"L�@}`yh$�tg��t�`jtr�~g�f-xt�2bz�r�b�b4*~dI_f92r�-%th��L;	,��%0 �;%�5RNch w{�#��	�	(�(`p5�t,Pqlz-�u��Z(`,� "�`��Xpd�&�~raaf�tJut�crqc,mL��p�+�;�P�$1|h'c|k^bͷ�0zr�N^B�i�di+cl,$)� ����oM  `�qdA2@,&'cApptL1seeoJDCk�5`v5x�i{GL��43&b �s( %0" !�@�0 0q@�!!$�   �|]�9��"00,$%�r52p�C�/����"(*!C�$ 0(b%JBur$�&�Ekgq�!K+*G `���G0C�e6C1 x�2gm���,��Ur|�e �b!�Ao`,(9	:w�n�c�-rm
q����/��$6k<g1; `-p&eQasd�m=?Nbr(U~N:e,�e(b #1AH#�YG� J�+j)v�f��z5O�@d3i}g-,bmpS+ A2wk?�b%g��Th�6/f�+�	(F`�W�zm��	fqvUaFc� 
#Ort��0� 3iRe
G* O�s���d�l�h$!�~���{�#pc�.u3i.��}�c�qgtH�lO|�ms<vm�s�3"�g ��`#�Vm3�n	`"kjOu��lCeve�� |HA� hd} �ocdx;ru}�e*Id@%P |7d�n2*��q��tCcug��`�A��|�?-&=fI&jg"�%��'@})uA�
��h,pos��8�*9K�h�Q^e�N9�d(�zed��-�i1I+zonV�iov2e*T`ҵ��w�)2$k��k�"/YA`�zt�hn2k�ybK'� c���<�*S>L	�(�)HhD�l ��8hM,��meaT�A8N�h�(�a+�1IIJu�\ng�fG��/)���o�Z�:a|ql+�q-M:Fl�(2)�U�A6b8!e_pCj�csm�nnH�%p�	)�YHI9k1Uq"
fx�`jf�	n'#���B;� la�e^d?Ml:hh��i�m%��>)ci�d-d"L�H?hi0e�la��d�bh2+�	�6m8,�"fz�v�"�*=
`�Wf02s�%2px��Lw,��gt`�;'�;B�yoM"6;�"���1(�-`p\4�`, p,:+�}��Z8`,�+�v�Lqt�$�tRI)f�uN`�! p# h��i�&�9�P���)|h 39(Vrͷ�Qrb�NVB� �Ah�ooln/o�(����.9`��!` �@(&"rEqpdL1weeoM�F  �4Eq`g08�og�\��53&j �s( %0b #�@�p 8uLT�a-$�'!d�x\�9�$�"GDs8-fe�Yv="r�A��+݋�� (( 2C�$Dp'e-�Cup$�&�Ekjp� J" E  ���0C�d'A1}�*fi���,��rt�er�l1�YKo( 9*v�&�"�):k
x����/ϭ'%s4bN1`!p $A`!d�(02`t*]zF8eh�f/g!gV5QJ"�G� H?)h!6�&��h1N�@a#i%-, $0(  w(>��b !��n�~/g�j�s-iBb�U�zo��-fq~EpCk= cNg%�� 0� ")PaG* �1�� l�lnkd(�2��#�^?�gsc�6u?j4���g�9!D �`oh�,b<f)�2� "�%`ؘ`"�F1h1�*  "cbJ5��lC!~m��)N � 0($$ �k!dz;rm}�g Pg@$L:x4h�,ro��`��tOg1f��b�A��|�?($=nM$je �m��g@y-As �
�� ( .o�y
8�"8I�(�a�_�f-F�zdl��5�J�	"zja^�!mf0dh0`����y�(50b��j�"&IJ�: �hf5j�}pC%�av�6L 9�*UC7^I	�(�eXiD�o!��8J_���i!Z�R6N�jd �a;�!Y	J|�\mg�dE��?o���k�^�?#.&*�0-M0$m3*2a�u�Avm8eZ`C3�gsi�jgLd-p�!�YPHhk1Q}2xb �`fV� `'k���R1�+La�e.&;Kl:j���k�o%�C�:ykko�-afL�D`ha$�le��tr�blan� �6(8$�"d{�t�c�"t�n`b0vs�	/&p(��Lw��E0r�;e�?VNek��r�2���9H�	pp4�`? plz/�u���tibl�g�j��Hq$��4�8�j!g�4Hsm�opyc,mZ��q�"�;�X��
!|h "8(R Ŷ�QrC�NQB� �eikeo|l-y� ���& E)"i� ` 8@   "r|tV9weerMFKk
�	5@9`558�)o_L��1}w'j �s( %4�h��@�08sLT�!o$�%!a�<T�9�,�"G 21.n'�1"p�A��"܉�� (oDarC��$@p e#J ur$�/�Dklp�cKn)Gd ���0� &@0    (not (or (eq m1b m1e) (eq m3b m3e)
                       (and (not (zerop (call-process diff-command
                                                      nil buf nil "-b" o m)))
                            ;; TODO: We don't know how to do the refinement
                            ;; if there's a non-empty ancestor and m1 and m3
                            ;; aren't just plain equal.
                            m2b (not (eq m2b m2e)))
                       (with-current-buffer buf
                         (goto-char (point-min))
                         ;; Make sure there's some refinement.
                         (looking-at
                          (concat "1," (number-to-string lines) "c"))))))
            (smerge-apply-resolution-patch buf m0b m0e m3b m3e m2b))
	   ;; "Mere whitespace changes" conflicts.
           ((when m2e
              (setq b (make-temp-file "smb"))
              (write-region m2b m2e b nil 'silent)
              (with-current-buffer buf (erase-buffer))
              ;; Only minor whitespace changes made locally.
              ;; BEWARE: pass "-c" 'cause the output is reused in the next test.
              (zerop (call-process diff-command nil buf nil "-bc" b m)))
            (set-match-data md)
	    (smerge-keep-n 3))
	   ;; Try "diff -b BASE MINE | patch OTHER".
	   ((when (and (not safe) m2e b
                       ;; If the BASE is empty, this would just concatenate
                       ;; the two, which is rarely right.
                       (not (eq m2b m2e)))
              ;; BEWARE: we're using here the patch of the previous test.
	      (with-current-buffer buf
		(zerop (call-process-region
			(point-min) (point-max) "patch" t nil nil
			"-r" null-device "--no-backup-if-mismatch"
			"-fl" o))))
	    (save-restriction
	      (narrow-to-region m0b m0e)
              (smerge-remove-props m0b m0e)
	      (insert-file-contents o nil nil nil t)))
	   ;; Try "diff -b BASE OTHER | patch MINE".
	   ((when (and (not safe) m2e b
                       ;; If the BASE is empty, this would just concatenate
                       ;; the two, which is rarely right.
                       (not (eq m2b m2e)))
	      (write-region m3b m3e o nil 'silent)
	      (call-process diff-command nil buf nil "-bc" b o)
	      (with-current-buffer buf
		(zerop (call-process-region
			(point-min) (point-max) "patch" t nil nil
			"-r" null-device "--no-backup-if-mismatch"
			"-fl" m))))
	    (save-restriction
	      (narrow-to-region m0b m0e)
              (smerge-remove-props m0b m0e)
	      (insert-file-contents m nil nil nil t)))
           ;; If the conflict is only made of comments, and one of the two
           ;; changes is only rearranging spaces (e.g. reflowing text) while
           ;; the other is a real change, drop the space-rearrangement.
           ((and m2e
                 (comment-only-p m1b m1e)
                 (comment-only-p m2b m2e)
                 (comment-only-p m3b m3e)
                 (let ((t1 (smerge-resolve--extract-comment m1b m1e))
                       (t2 (smerge-resolve--extract-comment m2b m2e))
                       (t3 (smerge-resolve--extract-comment m3b m3e)))
                   (cond
                    ((and (equal t1 t2) (not (equal t2 t3)))
                     (setq choice 3))
                    ((and (not (equal t1 t2)) (equal t2 t3))
                     (setq choice 1)))))
            (set-match-data md)
	    (smerge-keep-n choice))
           ;; Idem, when the conflict is contained within a single comment.
           ((save-excursion
              (and m2e
                   (nth 4 (syntax-ppss m0b))
                   ;; If there's a conflict earlier in the file,
                   ;; syntax-ppss is not reliable.
                   (not (re-search-backward smerge-begin-re nil t))
                   (progn (goto-char (nth 8 (syntax-ppss m0b)))
                          (forward-comment 1)
                          (> (point) m0e))
                   (let ((t1 (smerge-resolve--normalize m1b m1e))
                         (t2 (smerge-resolve--normalize m2b m2e))
                         (t3 (smerge-resolve--normalize m3b m3e)))
                     (cond
                    ((and (equal t1 t2) (not (equal t2 t3)))
                     (setq choice 3))
                    ((and (not (equal t1 t2)) (equal t2 t3))
                     (setq choice 1))))))
            (set-match-data md)
	    (smerge-keep-n choice))
           (t
            (user-error "Don't know how to resolve"))))
      (if (buffer-name buf) (kill-buffer buf))
      (if m (delete-file m))
      (if b (delete-file b))
      (if o (delete-file o))))
  (smerge-auto-leave))

(defun smerge-resolve-all ()
  "Perform automatic resolution on all conflicts."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward smerge-begin-re nil t)
      (condition-case nil
          (progn
            (smerge-match-conflict)
            (smerge-resolve 'safe))
        (error nil)))))

(defun smerge-batch-resolve ()
  ;; command-line-args-left is what is left of the command line.
  (if (not noninteractive)
      (error "`smerge-batch-resolve' is to be used only with -batch"))
  (while command-line-args-left
    (let ((file (pop command-line-args-left)))
      (if (string-match "\\.rej\\'" file)
          ;; .rej files should never contain diff3 markers, on the other hand,
          ;; in Arch, .rej files are sometimes used to indicate that the
          ;; main file has diff3 markers.  So you can pass **/*.rej and
          ;; it will DTRT.
          (setq file (substring file 0 (match-beginning 0))))
      (message "Resolving conflicts in %s..." file)
      (when (file-readable-p file)
        (with-current-buffer (find-file-noselect file)
          (smerge-resolve-all)
          (save-buffer)
          (kill-buffer (current-buffer)))))))

(defun smerge-keep-base ()
  "Revert to the base version."
  (interactive)
  (smerge-match-conflict)
  (smerge-ensure-match 2)
  (smerge-keep-n 2)
  (smerge-auto-leave))

(defun smerge-keep-other ()
  "Use \"other\" version."
  (interactive)
  (smerge-match-conflict)
  ;;(smerge-ensure-match 3)
  (smerge-keep-n 3)
  (smerge-auto-leave))

(defun smerge-keep-mine ()
  "Keep your version."
  (interactive)
  (smerge-match-conflict)
  ;;(smerge-ensure-match 1)
  (smerge-keep-n 1)
  (smerge-auto-leave))

(defun smerge-get-current ()
  (let ((i 3))
    (while (or (not (match-end i))
	       (< (point) (match-beginning i))
	       (>= (point) (match-end i)))
      (cl-decf i))
    i))

(defun smerge-keep-current ()
  "Use the current (under the cursor) version."
  (interactive)
  (smerge-match-conflict)
  (let ((i (smerge-get-current)))
    (if (<= i 0) (error "Not inside a version")
      (smerge-keep-n i)
      (smerge-auto-leave))))

(defun smerge-kill-current ()
  "Remove the current (under the cursor) version."
  (interactive)
  (smerge-match-conflict)
  (let ((i (smerge-get-current)))
    (if (<= i 0) (error "Not inside a version")
      (let ((left nil))
	(dolist (n '(3 2 1))
	  (if (and (match-end n) (/= (match-end n) (match-end i)))
	      (push n left)))
	(if (and (cdr left)
		 (/= (match-end (car left)) (match-end (cadr left))))
	    (ding)			;We don't know how to do that.
	  (smerge-keep-n (car left))
	  (smerge-auto-leave))))))

(defun smerge-diff-base-mine ()
  "Diff 'base' and 'mine' version in current conflict region."
  (interactive)
  (smerge-diff 2 1))

(defun smerge-diff-base-other ()
  "Diff 'base' and 'other' version in current conflict region."
  (interactive)
  (smerge-diff 2 3))

(defun smerge-diff-mine-other ()
  "Diff 'mine' and 'other' version in current conflict region."
  (interactive)
  (smerge-diff 1 3))

(defun smerge-match-conflict ()
  "Get info about the conflict.  Puts the info in the `match-data'.
The submatches contain:
 0:  the whole conflict.
 1:  your code.
 2:  the base code.
 3:  other code.
An error is raised if not inside a conflict."
  (save-excursion
    (condition-case nil
	(let* ((orig-point (point))

	       (_ (forward-line 1))
	       (_ (re-search-backward smerge-begin-re))

	       (start (match-beginning 0))
	       (mine-start (match-end 0))
	       (filename (or (match-string 1) ""))

	       (_ (re-search-forward smerge-end-re))
	       (_ (cl-assert (< orig-point (match-end 0))))

	       (other-end (match-beginning 0))
	       (end (match-end 0))

	       (_ (re-search-backward smerge-other-re start))

	       (mine-end (match-beginning 0))
	       (other-start (match-end 0))

	       base-start base-end)

	  ;; handle the various conflict styles
	  (cond
	   ((save-excursion
	      (goto-char mine-start)
	      (re-search-forward smerge-begin-re end t))
	    ;; There's a nested conflict and we're after the beginning
	    ;; of the outer one but before the beginning of the inner one.
	    ;; Of course, maybe this is not a nested conflict but in that
	    ;; case it can only be something nastier that we don't know how
	    ;; to handle, so may as well arbitrarily decide to treat it as
	    ;; a nested conflict.  --Stef
	    (error "There is a nested conflict"))

	   ((re-search-backward smerge-base-re start t)
	    ;; a 3-parts conflict
	    (set (make-local-variable 'smerge-conflict-style) 'diff3-A)
	    (setq base-end mine-end)
	    (setq mine-end (match-beginning 0))
	    (setq base-start (match-end 0)))

	   ((string= filename (file-name-nondirectory
			       (or buffer-file-name "")))
	    ;; a 2-parts conflict
	    (set (make-local-variable 'smerge-conflict-style) 'diff3-E))

	   ((and (not base-start)
		 (or (eq smerge-conflict-style 'diff3-A)
		     (equal filename "ANCESTOR")
		     (string-match "\\`[.0-9]+\\'" filename)))
	    ;; a same-diff conflict
	    (setq base-start mine-start)
	    (setq base-end   mine-end)
	    (setq mine-start other-start)
	    (setq mine-end   other-end)))

	  (store-match-data (list start end
				  mine-start mine-end
				  base-start base-end
				  other-start other-end
				  (when base-start (1- base-start)) base-start
				  (1- other-start) other-start))
	  t)
      (search-failed (user-error "Point not in conflict region")))))

(defun smerge-conflict-overlay (pos)
  "Return the conflict overlay at POS if any."
  (let ((ols (overlays-at pos))
        conflict)
    (dolist (ol ols)
      (if (and (eq (overlay-get ol 'smerge) 'conflict)
               (> (overlay-end ol) pos))
          (setq conflict ol)))
    conflict))

(defun smerge-find-conflict (&optional limit)
  "Find and match a conflict region.  Intended as a font-lock MATCHER.
The submatches are the same as in `smerge-match-conflict'.
Returns non-nil if a match is found between point and LIMIT.
Point is moved to the end of the conflict."
  (let ((found nil)
        (pos (point))
        conflict)
    ;; First check to see if point is already inside a conflict, using
    ;; the conflict overlays.
    (while (and (not found) (setq conflict (smerge-conflict-overlay pos)))
      ;; Check the overlay's validity and kill it if it's out of date.
      (condition-case nil
          (progn
            (goto-char (overlay-start conflict))
            (smerge-match-conflict)
            (goto-char (match-end 0))
            (if (<= (point) pos)
                (error "Matching backward!")
              (setq found t)))
        (error (smerge-remove-props
                (overlay-start conflict) (overlay-end conflict))
               (goto-char pos))))
    ;; If we're not already inside a conflict, look for the next conflict
    ;; and add/update its overlay.
    (while (and (not found) (re-search-forward smerge-begin-re limit t))
      (condition-case nil
          (progn
            (smerge-match-conflict)
            (goto-char (match-end 0))
            (let ((conflict (smerge-conflict-overlay (1- (point)))))
              (if conflict
                  ;; Update its location, just in case it got messed up.
                  (move-overlay conflict (match-beginning 0) (match-end 0))
                (setq conflict (make-overlay (match-beginning 0) (match-end 0)
                                             nil 'front-advance nil))
                (overlay-put conflict 'evaporate t)
                (overlay-put conflict 'smerge 'conflict)
                (let ((props smerge-text-properties))
                  (while props
                    (overlay-put conflict (pop props) (pop props))))))
            (setq found t))
        (error nil)))
    found))

;;; Refined change highlighting

(defvar smerge-refine-forward-function 'smerge-refine-forward
  "Function used to determine an \"atomic\" element.
You can set it to `forward-char' to get char-level granularity.
Its behavior has mainly two restrictions:
- if this function encounters a newline, it's important that it stops right
  after the newline.
  This only matters if `smerge-refine-ignore-whitespace' is nil.
- it needs to be unaffected by changes performed by the `preproc' argument
  to `smerge-refine-subst'.
  This only matters if `smerge-refine-weight-hack' is nil.")

(defvar smerge-refine-ignore-whitespace t
  "If non-nil, indicate that `smerge-refine' should try to ignore change in whitespace.")

(defvar smerge-refine-weight-hack t
  "If non-nil, pass to diff as many lines as there are chars in the region.
I.e. each atomic element (e.g. word) will be copied as many times (on different
lines) as it has chars.  This has two advantages:
- if `diff' tries to minimize the number *lines* (rather than chars)
  added/removed, this adjust the weights so that adding/removing long
  symbols is considered correspondingly more costly.
- `smerge-refine-forward-function' only needs to be called when chopping up
  the regions, and `forward-char' can be used afterwards.
It has the following disadvantages:
- cannot use `diff -w' because the weighting causes added spaces in a line
  to be represented as added copies of some line, so `diff -w' can't do the
  right thing any more.
- may in degenerate cases take a 1KB input region and turn it into a 1MB
  file to pass to diff.")

(defun smerge-refine-forward (n)
  (let ((case-fold-search nil)
        (re "[[:upper:]]?[[:lower:]]+\\|[[:upper:]]+\\|[[:digit:]]+\\|.\\|\n"))
    (when (and smerge-refine-ignore-whitespace
               ;; smerge-refine-weight-hack causes additional spaces to
               ;; appear as additional lines as well, so even if diff ignore
               ;; whitespace changes, it'll report added/removed lines :-(
               (not smerge-refine-weight-hack))
      (setq re (concat "[ \t]*\\(?:" re "\\)")))
    (dotimes (_i n)
      (unless (looking-at re) (error "Smerge refine internal error"))
      (goto-char (match-end 0)))))

(defun smerge-refine-chopup-region (beg end file &optional preproc)
  "Chopup the region into small elements, one per line.
Save the result into FILE.
If non-nil, PREPROC is called with no argument in a buffer that contains
a copy of the text, just before chopping it up.  It can be used to replace
chars to try and eliminate some spurious differences."
  ;; We used to chop up char-by-char rather than word-by-word like ediff
  ;; does.  It had the benefit of simplicity and very fine results, but it
  ;; often suffered from problem that diff would find correlations where
  ;; there aren't any, so the resulting "change" didn't make much sense.
  ;; You can still get this behavior by setting
  ;; `smerge-refine-forward-function' to `forward-char'.
  (let ((buf (current-buffer)))
    (with-temp-buffer
      (insert-buffer-substring buf beg end)
      (when preproc (goto-char (point-min)) (funcall preproc))
      (when smerge-refine-ignore-whitespace
        ;; It doesn't make much of a difference for diff-fine-highlight
        ;; because we still have the _/+/</>/! prefix anyway.  Can still be
        ;; useful in other circumstances.
        (subst-char-in-region (point-min) (point-max) ?\n ?\s))
      (goto-char (point-min))
      (while (not (eobp))
        (funcall smerge-refine-forward-function 1)
        (let ((s (if (prog2 (forward-char -1) (bolp) (forward-char 1))
                     nil
                   (buffer-substring (line-beginning-position) (point)))))
          ;; We add \n after each char except after \n, so we get
          ;; one line per text char, where each line contains
          ;; just one char, except for \n chars which are
          ;; represented by the empty line.
          (unless (eq (char-before) ?\n) (insert ?\n))
          ;; HACK ALERT!!
          (if smerge-refine-weight-hack
              (dotimes (_i (1- (length s))) (insert s "\n")))))
      (unless (bolp) (error "Smerge refine internal error"))
      (let ((coding-system-for-write 'emacs-mule))
        (write-region (point-min) (point-max) file nil 'nomessage)))))

(defun smerge-refine-highlight-change (buf beg match-num1 match-num2 props)
  (with-current-buffer buf
    (goto-char beg)
    (let* ((startline (- (string-to-number match-num1) 1))
           (beg (progn (funcall (if smerge-refine-weight-hack
                                    'forward-char
                                  smerge-refine-forward-function)
                                startline)
                       (point)))
           (end (progn (funcall (if smerge-refine-weight-hack
                                    'forward-char
                                  smerge-refine-forward-function)
                          (if match-num2
                              (- (string-to-number match-num2)
                                 startline)
                            1))
                       (point))))
      (when smerge-refine-ignore-whitespace
        (skip-chars-backward " \t\n" beg) (setq end (point))
        (goto-char beg)
        (skip-chars-forward " \t\n" end)  (setq beg (point)))
      (when (> end beg)
        (let ((ol (make-overlay
                   beg end nil
                   ;; Make them tend to shrink rather than spread when editing.
                   'front-advance nil)))
          (overlay-put ol 'evaporate t)
          (dolist (x props) (overlay-put ol (car x) (cdr x)))
          ol)))))

(defun smerge-refine-subst (beg1 end1 beg2 end2 props-c &optional preproc props-r props-a)
  "Show fine differences in the two regions BEG1..END1 and BEG2..END2.
PROPS-C is an alist of properties to put (via overlays) on the changes.
PROPS-R is an alist of properties to put on removed characters.
PROPS-A is an alist of properties to put on added characters.
If PROPS-R and PROPS-A are nil, put PROPS-C on all changes.
If PROPS-C is nil, but PROPS-R and PROPS-A are non-nil,
put PROPS-A on added characters, PROPS-R on removed characters.
If PROPS-C, PROPS-R and PROPS-A are non-nil, put PROPS-C on changed characters,
PROPS-A on added characters, and PROPS-R on removed characters.

If non-nil, PREPROC is called with no argument in a buffer that contains
a copy of a region, just before preparing it to for `diff'.  It can be
used to replace chars to try and eliminate some spurious differences."
  (let* ((buf (current-buffer))
         (pos (point))
         deactivate-mark         ; The code does not modify any visible buffer.
         (file1 (make-temp-file "diff1"))
         (file2 (make-temp-file "diff2")))
    ;; Chop up regions into smaller elements and save into files.
    (smerge-refine-chopup-region beg1 end1 file1 preproc)
    (smerge-refine-chopup-region beg2 end2 file2 preproc)

    ;; Call diff on those files.
    (unwind-protect
        (with-temp-buffer
          (let ((coding-system-for-read 'emacs-mule))
            (call-process diff-command nil t nil
                          (if (and smerge-refine-ignore-whitespace
                                   (not smerge-refine-weight-hack))
                              ;; Pass -a so diff treats it as a text file even
                              ;; if it contains \0 and such.
                              ;; Pass -d so as to get the smallest change, but
                              ;; also and more importantly because otherwise it
                              ;; may happen that diff doesn't behave like
                              ;; smerge-refine-weight-hack expects it to.
                              ;; See http://thread.gmane.org/gmane.emacs.devel/82685.
                              "-awd" "-ad")
                          file1 file2))
          ;; Process diff's output.
          (goto-char (point-min))
          (let ((last1 nil)
                (last2 nil))
            (while (not (eobp))
              (if (not (looking-at "\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)?\\([acd]\\)\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)?$"))
                  (error "Unexpected patch hunk header: %s"
                         (buffer-substring (point) (line-end-position))))
              (let ((op (char-after (match-beginning 3)))
                    (m1 (match-string 1))
                    (m2 (match-string 2))
                    (m4 (match-string 4))
                    (m5 (match-string 5)))
                (when (memq op '(?d ?c))
                  (setq last1
                        (smerge-refine-highlight-change
			 buf beg1 m1 m2
			 ;; Try to use props-c only for changed chars,
			 ;; fallback to props-r for changed/removed chars,
			 ;; but if props-r is nil then fallback to props-c.
			 (or (and (eq op '?c) props-c) props-r props-c))))
                (when (memq op '(?a ?c))
                  (setq last2
                        (smerge-refine-highlight-change
			 buf beg2 m4 m5
			 ;; Same logic as for removed chars above.
			 (or (and (eq op '?c) props-c) props-a props-c)))))
              (forward-line 1)                            ;Skip hunk header.
              (and (re-search-forward "^[0-9]" nil 'move) ;Skip hunk body.
                   (goto-char (match-beginning 0))))
            ;; (cl-assert (or (null last1) (< (overlay-start last1) end1)))
            ;; (cl-assert (or (null last2) (< (overlay-start last2) end2)))
            (if smerge-refine-weight-hack
                (progn
                  ;; (cl-assert (or (null last1) (<= (overlay-end last1) end1)))
                  ;; (cl-assert (or (null last2) (<= (overlay-end last2) end2)))
                  )
              ;; smerge-refine-forward-function when calling in chopup may
              ;; have stopped because it bumped into EOB whereas in
              ;; smerge-refine-weight-hack it may go a bit further.
              (if (and last1 (> (overlay-end last1) end1))
                  (move-overlay last1 (overlay-start last1) end1))
              (if (and last2 (> (overlay-end last2) end2))
                  (move-overlay last2 (overlay-start last2) end2))
              )))
      (goto-char pos)
      (delete-file file1)
      (delete-file file2))))

(defun smerge-refine (&optional part)
  "Highlight the words of the conflict that are different.
For 3-way conflicts, highlights only two of the three parts.
A numeric argument PART can be used to specify which two parts;
repeating the command will highlight other two parts."
  (interactive
   (if (integerp current-prefix-arg) (list current-prefix-arg)
     (smerge-match-conflict)
     (let* ((prop (get-text-property (match-beginning 0) 'smerge-refine-part))
            (part (if (and (consp prop)
                           (eq (buffer-chars-modified-tick) (car prop)))
                      (cdr prop))))
       ;; If already highlighted, cycle.
       (list (if (integerp part) (1+ (mod part 3)))))))

  (if (and (integerp part) (or (< part 1) (> part 3)))
      (error "No conflict part nb %s" part))
  (smerge-match-conflict)
  (remove-overlays (match-beginning 0) (match-end 0) 'smerge 'refine)
  ;; Ignore `part' if not applicable, and default it if not provided.
  (setq part (cond ((null (match-end 2)) 2)
                   ((eq (match-end 1) (match-end 3)) 1)
                   ((integerp part) part)
                   ;; If one of the parts is empty, any refinement using
                   ;; it will be trivial and uninteresting.
                   ((eq (match-end 1) (match-beginning 1)) 1)
                   ((eq (match-end 3) (match-beginning 3)) 3)
                   (t 2)))
  (let ((n1 (if (eq part 1) 2 1))
        (n2 (if (eq part 3) 2 3))
	(smerge-use-changed-face
	 (and (face-differs-from-default-p 'smerge-refined-change)
	      (not (face-equal 'smerge-refined-change 'smerge-refined-added))
	      (not (face-equal 'smerge-refined-change 'smerge-refined-removed)))))
    (smerge-ensure-match n1)
    (smerge-ensure-match n2)
    (with-silent-modifications
      (put-text-property (match-beginning 0) (1+ (match-beginning 0))
                         'smerge-refine-part
                         (cons (buffer-chars-modified-tick) part)))
    (smerge-refine-subst (match-beginning n1) (match-end n1)
                         (match-beginning n2)  (match-end n2)
                         (if smerge-use-changed-face
			     '((smerge . refine) (face . smerge-refined-change)))
			 nil
			 (unless smerge-use-changed-face
			   '((smerge . refine) (face . smerge-refined-removed)))
			 (unless smerge-use-changed-face
			   '((smerge . refine) (face . smerge-refined-added))))))

(defun smerge-diff (n1 n2)
  (smerge-match-conflict)
  (smerge-ensure-match n1)
  (smerge-ensure-match n2)
  (let ((name1 (aref smerge-match-names n1))
	(name2 (aref smerge-match-names n2))
	;; Read them before the match-data gets clobbered.
	(beg1 (match-beginning n1))
	(end1 (match-end n1))
	(beg2 (match-beginning n2))
	(end2 (match-end n2))
	(file1 (make-temp-file "smerge1"))
	(file2 (make-temp-file "smerge2"))
	(dir default-directory)
	(file (if buffer-file-name (file-relative-name buffer-file-name)))
        ;; We would want to use `emacs-mule-unix' for read&write, but we
        ;; bump into problems with the coding-system used by diff to write
        ;; the file names and the time stamps in the header.
        ;; `buffer-file-coding-system' is not always correct either, but if
        ;; the OS/user uses only one coding-system, then it works.
	(coding-system-for-read buffer-file-coding-system))
    (write-region beg1 end1 file1 nil 'nomessage)
    (write-region beg2 end2 file2 nil 'nomessage)
    (unwind-protect
	(with-current-buffer (get-buffer-create smerge-diff-buffer-name)
	  (setq default-directory dir)
	  (let ((inhibit-read-only t))
	    (erase-buffer)
	    (let ((status
		   (apply 'call-process diff-command nil t nil
			  (append smerge-diff-switches
				  (list "-L" (concat name1 "/" file)
					"-L" (concat name2 "/" file)
					file1 file2)))))
	      (if (eq status 0) (insert "No differences found.\n"))))
	  (goto-char (point-min))
	  (diff-mode)
	  (display-buffer (current-buffer) t))
      (delete-file file1)
      (delete-file file2))))

;; compiler pacifiers
(defvar smerge-ediff-windows)
(defvar smerge-ediff-buf)
(defvar ediff-buffer-A)
(defvar ediff-buffer-B)
(defvar ediff-buffer-C)
(defvar ediff-ancestor-buffer)
(defvar ediff-quit-hook)
(declare-function ediff-cleanup-mess "ediff-util" nil)

(defun smerge--get-marker (regexp default)
  (save-excursion
    (goto-char (point-min))
    (if (and (search-forward-regexp regexp nil t)
	     (> (match-end 1) (match-beginning 1)))
	(concat default "=" (match-string-no-properties 1))
      default)))

;;;###autoload
(defun smerge-ediff (&optional name-mine name-other name-base)
  "Invoke ediff to resolve the conflicts.
NAME-MINE, NAME-OTHER, and NAME-BASE, if non-nil, are used for the
buffer names."
  (interactive)
  (let* ((buf (current-buffer))
	 (mode major-mode)
	 ;;(ediff-default-variant 'default-B)
	 (config (current-window-configuration))
	 (filename (file-name-nondirectory (or buffer-file-name "-")))
	 (mine (generate-new-buffer
		(or name-mine
                    (concat "*" filename " "
                            (smerge--get-marker smerge-begin-re "MINE")
                            "*"))))
	 (other (generate-new-buffer
		 (or name-other
                     (concat "*" filename " "
                             (smerge--get-marker smerge-end-re "OTHER")
                             "*"))))
	 base)
    (with-current-buffer mine
      (buffer-disable-undo)
      (insert-buffer-substring buf)
      (goto-char (point-min))
      (while (smerge-find-conflict)
	(when (match-beginning 2) (setq base t))
	(smerge-keep-n 1))
      (buffer-enable-undo)
      (set-buffer-modified-p nil)
      (funcall mode))

    (with-current-buffer other
      (buffer-disable-undo)
      (insert-buffer-substring buf)
      (goto-char (point-min))
      (while (smerge-find-conflict)
	(smerge-keep-n 3))
      (buffer-enable-undo)
      (set-buffer-modified-p nil)
      (funcall mode))

    (when base
      (setq base (generate-new-buffer
		  (or name-base
                      (concat "*" filename " "
                              (smerge--get-marker smerge-base-re "BASE")
                              "*"))))
      (with-current-buffer base
	(buffer-disable-undo)
	(insert-buffer-substring buf)
	(goto-char (point-min))
	(while (smerge-find-conflict)
	  (if (match-end 2)
	      (smerge-keep-n 2)
	    (delete-region (match-beginning 0) (match-end 0))))
	(buffer-enable-undo)
	(set-buffer-modified-p nil)
	(funcall mode)))

    ;; the rest of the code is inspired from vc.el
    ;; Fire up ediff.
    (set-buffer
     (if base
	 (ediff-merge-buffers-with-ancestor mine other base)
	  ;; nil 'ediff-merge-revisions-with-ancestor buffer-file-name)
       (ediff-merge-buffers mine other)))
        ;; nil 'ediff-merge-revisions buffer-file-name)))

    ;; Ediff is now set up, and we are in the control buffer.
    ;; Do a few further adjustments and take precautions for exit.
    (set (make-local-variable 'smerge-ediff-windows) config)
    (set (make-local-variable 'smerge-ediff-buf) buf)
    (set (make-local-variable 'ediff-quit-hook)
	 (lambda ()
	   (let ((buffer-A ediff-buffer-A)
		 (buffer-B ediff-buffer-B)
		 (buffer-C ediff-buffer-C)
		 (buffer-Ancestor ediff-ancestor-buffer)
		 (buf smerge-ediff-buf)
		 (windows smerge-ediff-windows))
	     (ediff-cleanup-mess)
	     (with-current-buffer buf
	       (erase-buffer)
	       (insert-buffer-substring buffer-C)
	       (kill-buffer buffer-A)
	       (kill-buffer buffer-B)
	       (kill-buffer buffer-C)
	       (when (bufferp buffer-Ancestor) (kill-buffer buffer-Ancestor))
	       (set-window-configuration windows)
	       (message "Conflict resolution finished; you may save the buffer")))))
    (message "Please resolve conflicts now; exit ediff when done")))

(defun smerge-makeup-conflict (pt1 pt2 pt3 &optional pt4)
  "Insert diff3 markers to make a new conflict.
Uses point and mark for two of the relevant positions and previous marks
for the other ones.
By default, makes up a 2-way conflict,
with a \\[universal-argument] prefix, makes up a 3-way conflict."
  (interactive
   (list (point)
         (mark)
         (progn (pop-mark) (mark))
         (when current-prefix-arg (pop-mark) (mark))))
  ;; Start from the end so as to avoid problems with pos-changes.
  (pcase-let ((`(,pt1 ,pt2 ,pt3 ,pt4)
               (sort `(,pt1 ,pt2 ,pt3 ,@(if pt4 (list pt4))) '>=)))
    (goto-char pt1) (beginning-of-line)
    (insert ">>>>>>> OTHER\n")
    (goto-char pt2) (beginning-of-line)
    (insert "=======\n")
    (goto-char pt3) (beginning-of-line)
    (when pt4
      (insert "||||||| BASE\n")
      (goto-char pt4) (beginning-of-line))
    (insert "<<<<<<< MINE\n"))
  (if smerge-mode nil (smerge-mode 1))
  (smerge-refine))


(defconst smerge-parsep-re
  (concat smerge-begin-re "\\|" smerge-end-re "\\|"
          smerge-base-re "\\|" smerge-other-re "\\|"))

;;;###autoload
(define-minor-mode smerge-mode
  "Minor mode to simplify editing output from the diff3 program.
With a prefix argument ARG, enable the mode if ARG is positive,
and disable it otherwise.  If called from Lisp, enable the mode
if ARG is omitted or nil.
\\{smerge-mode-map}"
  :group 'smerge :lighter " SMerge"
  (when (and (boundp 'font-lock-mode) font-lock-mode)
    (save-excursion
      (if smerge-mode
	  (font-lock-add-keywords nil smerge-font-lock-keywords 'append)
	(font-lock-remove-keywords nil smerge-font-lock-keywords))
      (goto-char (point-min))
      (while (smerge-find-conflict)
	(save-excursion
	  (font-lock-fontify-region (match-beginning 0) (match-end 0) nil)))))
  (if (string-match (regexp-quote smerge-parsep-re) paragraph-separate)
      (unless smerge-mode
        (set (make-local-variable 'paragraph-separate)
             (replace-match "" t t paragraph-separate)))
    (when smerge-mode
        (set (make-local-variable 'paragraph-separate)
             (concat smerge-parsep-re paragraph-separate))))
  (unless smerge-mode
    (smerge-remove-props (point-min) (point-max))))

;;;###autoload
(defun smerge-start-session ()
  "Turn on `smerge-mode' and move point to first conflict marker.
If no conflict maker is found, turn off `smerge-mode'."
  (interactive)
  (smerge-mode 1)
  (condition-case nil
      (unless (looking-at smerge-begin-re)
        (smerge-next))
    (error (smerge-auto-leave))))

(provide 'smerge-mode)

;;; smerge-mode.el ends here
