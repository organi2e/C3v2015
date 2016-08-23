# C3
C³, Chained-Cauchy-Cell.  
An implementation of probabilistic multi-layered perceptron.  
All connection weights and biases depend on [Stable distribution](https://wikipedia.org/wiki/Stable_distribution).   
The signal propagation gets randomly determined.  
In current implementation, they depend on [Cauchy distribution](https://wikipedia.org/wiki/Cauchy_distribution).   
  
Their cells can take only binary states, 0 and 1, meaning NOT FIRED and FIRED,   
similat to general multi-layered perceptron.  
The common of learning law is similar to general neural network and backpropagation algorithm.  
They however employ several improved techniques such as sign propagation for binary statement.  
