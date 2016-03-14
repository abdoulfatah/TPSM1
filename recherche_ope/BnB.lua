--lire un fichier pour extraire une liste de poids et valeurs
value={1,2,3,4,5}
weight={6,7,8,9,10}
ratio={}
W=24
--nb d'elts au total (i.e. taille de value, et de weight)
N=5
--contiendra, a la fin de l'exec, l'ensemble le plus optimal d'objets
final_bag={}
for i=1,N do final_bag[i]=false end
--variable globale pour le calcul du remplissage le plus efficace
max=-1

local function p(tab)
   for i=1,N do
      print(tab[i])
   end
end

--ordonner les objets par ratio decroissant, il faut utiliser une matrice pour se souvenir de l'indice associe a un ratio
local function fill_ratios()
   for i=1,N do
      ratio[i]={}
      ratio[i][1]=i
      ratio[i][2]=value[i]/weight[i]
   end
   table.sort(ratio,function(a,b) return a[2]>b[2] end)
end

local function copy(src)
   local dest={}
   local n=#src
   for i=1,n do
      dest[i] = src[i]
   end
   return dest
end

--determiner une borne superieure de la valeur du sac
local function upper_thresh_value()
   local w=0
   local i=1
   local v=0
   while w<=W and i<=N do
      w=w+weight[ratio[i][1]]
      v=v+value[ratio[i][1]]
      i=i+1
   end
   if w>W then
      --on retourne un cran an arriere car on veut modifier le resultat de la derniere iteration
      i=i-1
      --diff est l'excedent de poids que l'on veut enlever
      local diff=w-W
      --frac est le pourcentage du poids du dernier elt a enlever de la valeur du sac
      local frac=diff/weight[ratio[i][1]]
      v=v-(frac*value[ratio[i][1]])
      w=w-(frac*weight[ratio[i][1]])
   end
   return v
end

local function local_thresh_value(bag)
   local w=0
   local i=1
   local v=0
   while w<=W and i<=N do
      if not bag[i] then
	 w=w+weight[ratio[i][1]]
	 v=v+value[ratio[i][1]]
      end
      i=i+1
   end
   if w>W then
      i=i-1
      while bag[i] do i=i-1 end
      local diff=w-W
      local frac=diff/weight[ratio[i][1]]
      v=v-(frac*value[ratio[i][1]])
      w=w-(frac*weight[ratio[i][1]])
   end
   return v
end

--calcul de la valeur de l'ensemble des objets contenus dnas le sac (materialise par un tableau de bool)
local function sum_values(in_bag)
   local v=0
   for i=1,N do
      if(in_bag[i]) then
	 v = v+value[i]
      end
   end
   return v
end

--verifie si les objets contenus dans le sac (represente par un tableau de bool) ne depasse pas le poids limite
local function check_weight(in_bag)
   local w=0
   local i=1
   while i<=N and w<=W do
      if(in_bag[i]) then
	 w = w+weight[i]
      end
      i=i+1
   end
   if w>W then return -1
   else return w end
end

--calcul de tous les sous-ensembles possibles pour trouver le remplissage optimal
local function fill_bag_exhaustive(in_bag, indice)
   --on traite d'abord le cas terminal : est-ce que notre tableau in_bag represente un cas d'arret ?
   local w=check_weight(in_bag)
   local ret
   
   --si on a depasse la valeur de poids limite, pas bon, on retourne -1
   if w==-1 or local_thresh_value(in_bag)<=max then 
      ret=-1

      --si on est arrive pile au poids limite, on ne cherche pas plus loin et on retourne la valeur de notre sac
      --si on est a la fin de l'arbre (indice == nb d'objets dispos) idem
   elseif w==W or indice==N then 
      ret=sum_values(in_bag)
      if(ret>max) then
	 max = ret
	 final_bag=in_bag
      end
      
      --enfin si on peut (probablement) encore rajouter des objets, on continue les appels recursifs
   else
      --creation de deux tableaux de presence, pour la branche droite et gauche
      --dans un cas on rajoute l'elt numero "indice" a notre sac, dans l'autre non
      local in_bag_1 = copy(in_bag)
      local in_bag_2 = copy(in_bag)
      in_bag_1[indice] = true
      
      --appels recursifs
      local x,y
      local x=fill_bag_exhaustive(in_bag_1,indice+1)
      local y=fill_bag_exhaustive(in_bag_2,indice+1)
      ret = math.max(w,math.max(x,y))

      if ret>max then
	 max=ret
	 if ret==w then
	    final_bag=in_bag
	 elseif ret==x then
	    final_bag=in_bag_1
	 elseif ret==y then
	    final_bag=in_bag_2
	 end
      end
   end
   return ret
end

--test des fonctions
fill_ratios()
--[[for i=1,N do
   print(ratio[i][1])
   print(ratio[i][2])
   end]]--

local thresh = upper_thresh_value()
--print(thresh)

local in_bag={}
for i=1,N do
   in_bag[i]=false
end
print(fill_bag_exhaustive(in_bag,1))

p(final_bag)


