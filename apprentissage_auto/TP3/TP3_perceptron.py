
import numpy as np
from pylab import rand,plot,show,norm



threshold = 0.5
learning_rate = 1


def generateData(n):
 """
  generates a 2D linearly separable dataset with n samples.
  The third element of the sample is the label
 """
 xb = (rand(n)*2-1)/2-0.5
 yb = (rand(n)*2-1)/2+0.5
 xr = (rand(n)*2-1)/2+0.5
 yr = (rand(n)*2-1)/2-0.5
 inputs = []
 for i in range(len(xb)):
  inputs.append(((xb[i],yb[i]),0))
  inputs.append(((xr[i],yr[i]),1))
 return inputs



def dot_product(values, weights):
    return sum(value * weight for value, weight in zip(values,weights))


def perceptron(weights, training_set):
 while True:
    print('-' * 60)
    error_count = 0
    for input_vector, desired_output in training_set:
        #np.set_printoptions(formatter={'float': '{: 0.3f}'.format})
        #print(weights)
        #print(np.array(weights))
        result = dot_product(input_vector,weights) > threshold
        error = desired_output - result
        if error != 0:
            error_count +=1
            for index, value in enumerate(input_vector):
                weights[index] += learning_rate * error * value
    if error_count == 0:
        break
 return weights






weights = [0,0]
training_set = generateData(30)

weights = perceptron(weights, training_set)



for x in training_set:
 if x[1] == 1:
  plot(x[0][0],x[0][1],'ob')
 else:
  plot(x[0][0],x[0][1],'or')

n = norm(weights)
ww = weights/n
ww1 = [ww[1],-ww[0]]
ww2 = [-ww[1],ww[0]]
plot([ww1[0], ww2[0]],[ww1[1], ww2[1]],'--k')

show()
