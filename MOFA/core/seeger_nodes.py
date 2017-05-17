from __future__ import division
import scipy as s
import numpy.ma as ma

from variational_nodes import Unobserved_Variational_Node
from nodes import Node
from utils import sigmoid, lambdafn

"""
Module to define updates for non-conjugate matrix factorisation models using the Seeger approach
Reference: 'Fast Variational Bayesian Inference for Non-Conjugate Matrix Factorisation models' by Seeger and Bouchard (2012)
"""


################
## Pseudodata ##
################

class PseudoY(Unobserved_Variational_Node):
    """
    General class for pseudodata nodes
    """
    def __init__(self, dim, obs, Zeta=None, E=None):
        # Inputs:
        #  dim (2d tuple): dimensionality of each view
        #  obs (ndarray): observed data
        #  Zeta: parameter (see reference paper)
        #  E (ndarray): initial expected value of pseudodata
        Unobserved_Variational_Node.__init__(self, dim)

        # Initialise observed data
        assert obs.shape == dim, "Problems with the dimensionalities"
        self.obs = obs

        # Initialise Zeta
        self.Zeta = Zeta

        # Create a boolean mask of the data to hidden missing values
        if type(self.obs) != ma.MaskedArray:
            self.mask()

        # Precompute some terms
        # self.precompute()

        # Initialise expectation
        if E is not None:
            assert E.shape == dim, "Problems with the dimensionalities"
            E = ma.masked_invalid(E)
        # else:
            # E = ma.masked_invalid(s.zeros(self.dim))
        self.E = E
    def updateParameters(self):
        Z = self.markov_blanket["Z"].getExpectation()
        SW = self.markov_blanket["SW"].getExpectation()
        self.Zeta = s.dot(Z,SW.T)

    def mask(self):
        # Mask the observations if they have missing values
        self.obs = ma.masked_invalid(self.obs)

    def precompute(self):
        # Precompute some terms to speed up the calculations
        pass

    def updateExpectations(self):
        print "Expectation updates for pseudodata node depend on the type of likelihood. They have to be specified in a child class."
        exit()
        pass

    def getExpectation(self):
        return self.E

    def getExpectations(self):
        return { 'E':self.getExpectation() }

    def getObservations(self):
        return self.obs

    def getValue(self):
        return self.obs

    def getParameters(self):
        return { 'zeta':self.Zeta }

    def calculateELBO(self):
        print "Not implemented"
        exit()

##################
## Seeger nodes ##
##################

class Poisson_PseudoY(PseudoY):
    """
    Class for a Poisson pseudodata node with the following likelihood:
        p(y|x) \prop gamma(x) * e^{-gamma(x)}  (1)
    where gamma(x) is a rate function that is chosen to be convex and log-concave
    A simple choise for the rate function is e^{x} but this rate function is non-robust
    in the presence of outliers, so in Seeger et al they chose the function:
        gamma(x) = log(1+e^x)

    The data follows a Poisson distribution, but Followung Seeger et al the pseudodata Yhat_ij
    follows a normal distribution with mean E[W_{i,:}]*E[Z_{j,:}] and precision 'tau_j'
    where 'tau_j' is an upper bound of the second derivative of the loglikelihood:
        x_ij = sum_k^k w_{i,k}*z_{k,j}
        f_ij''(x_ij) <= tau_j for all i,j

    For the Poisson likelihood with rate function (1), the upper bound tau is calculated as follows:
        f_ij''(x_ij) = 0.25 + 0.17*ymax_j   where ymax_j = max(Y_{:,j})

    Pseudodata is updated as follows:
        yhat_ij = zeta_ij - f'(zeta_ij)/tau_j = ...
    The bound degrades with the presence of entries with large y_ij, so one should consider
    clipping overly large counts

    """
    def __init__(self, dim, obs, Zeta=None, E=None):
        # - dim (2d tuple): dimensionality of each view
        # - obs (ndarray): observed data
        # - E (ndarray): initial expected value of pseudodata
        PseudoY.__init__(self, dim=dim, obs=obs, Zeta=Zeta, E=E)

        # Initialise the observed data
        assert s.all(s.mod(self.obs, 1) == 0), "Data must not contain float numbers, only integers"
        assert s.all(self.obs >= 0), "Data must not contain negative numbers"

    def ratefn(self, X):
        # Poisson rate function
        return s.log(1+s.exp(X))

    def clip(self, threshold):
        # The local bound degrades with the presence of large values in the observed data, which should be clipped
        pass

    def updateExpectations(self):
        # Update the pseudodata
        tau = self.markov_blanket["Tau"].getValue()
        self.E = self.Zeta - sigmoid(self.Zeta)*(1-self.obs/self.ratefn(self.Zeta))/tau[None,:]

    def calculateELBO(self):
        # Compute Lower Bound using the Poisson likelihood with observed data
        Z = self.markov_blanket["Z"].getExpectation()
        SW = self.markov_blanket["SW"].getExpectation()
        tmp = self.ratefn(s.dot(Z,SW.T))
        lb = s.sum( self.obs*s.log(tmp) - tmp)
        return lb
class Bernoulli_PseudoY(PseudoY):
    """
    Class for a Bernoulli (0,1 data) pseudodata node with the following likelihood:
        p(y|x) = (e^{yx}) / (1+e^x)  (1)
        f(x) = -log p(y|x) = log(1+e^x) - yx

    The second derivative is upper bounded by tau=0.25

    Folloiwng Seeger et al, the data follows a Bernoulli distribution but the pseudodata follows a
    normal distribution with mean E[W]*E[Z] and precision 'tau'

    IMPROVE EXPLANATION

    Pseudodata is updated as follows:
        yhat_ij = zeta_ij - f'(zeta_ij)/tau
                = zeta_ij - 4*(sigmoid(zeta_ij) - y_ij)

    """
    def __init__(self, dim, obs, Zeta=None, E=None):
        # - dim (2d tuple): dimensionality of each view
        # - obs (ndarray): observed data
        # - E (ndarray): initial expected value of pseudodata
        PseudoY.__init__(self, dim=dim, obs=obs, Zeta=Zeta, E=E)

        # Initialise the observed data
        assert s.all( (self.obs==0) | (self.obs==1) ), "Data must be binary"

    def updateExpectations(self):
        # Update the pseudodata
        self.E = self.Zeta - 4.*(sigmoid(self.Zeta) - self.obs)

    def calculateELBO(self):
        # Compute Lower Bound using the Bernoulli likelihood with observed data
        Z = self.markov_blanket["Z"].getExpectation()
        SW = self.markov_blanket["SW"].getExpectation()
        tmp = s.dot(Z,SW.T)
        lik = s.sum( self.obs*tmp - s.log(1+s.exp(tmp)) )
        return lik
class Binomial_PseudoY(PseudoY):
    """
    Class for a Binomial pseudodata node with the following likelihood:
        p(x|N,theta) = p(x|N,theta) = binom(N,x) * theta**(x) * (1-theta)**(N-x)
        f(x) = -log p(x|N,theta) = -log(binom(N,x)) - x*theta - (N-x)*(1-theta)

    The second derivative is upper bounded:
        f''(x_ij) <= 0.25*max(N_{:,j})

    Folloiwng Seeger et al, the pseudodata yhat_{nd} follows a normal distribution with mean
    E[w_{i,:}]*E[z_{j,:}] and precision 'tau_j'

    IMPROVE EXPLANATION

    Pseudodata is updated as follows
        yhat_ij = zeta_ij - f'(zeta_ij)/tau_j
                = zeta_ij - (N_{ij}*sigmoid(zeta_ij) - y_ij)/tau_d

    """
    def __init__(self, dim, obs, tot, Zeta=None, E=None):
        # - dim (2d tuple): dimensionality of each view
        # - obs (ndarray): observed data
        # - E (ndarray): initial expected value of pseudodata
        PseudoY.__init__(self, dim=dim, obs=None, Zeta=Zeta, E=E)

        # Initialise the observed data
        assert s.all(s.mod(obs, 1) == 0) and s.all(s.mod(tot, 1) == 0), "Data must not contain float numbers, only integers"
        assert s.all(obs >= 0) and s.all(tot >= 0), "Data must not contain negative numbers"
        assert s.all(obs <= tot), "Observed counts have to be equal or smaller than the total counts"
        self.obs = obs
        self.tot = tot


    def updateExpectations(self):
        # Update the pseudodata
        tau = self.markov_blanket["Tau"].getValue()
        self.E = self.zeta - s.divide(self.tot*sigmoid(self.Zeta)-self.obs, tau)
        pass

    def calculateELBO(self):
        # Compute Lower Bound using the Bernoulli likelihood with observed data
        Z = self.markov_blanket["Z"].getExpectation()
        SW = self.markov_blanket["SW"].getExpectation()

        tmp = sigmoid(s.dot(Z,SW.T))

        # TODO change apprximation
        tmp[tmp==0] = 0.00000001
        tmp[tmp==1] = 0.99999999
        lik = s.log(s.special.binom(self.tot,self.obs)).sum() + s.sum(self.obs*s.log(tmp)) + \
            s.sum((self.tot-self.obs)*s.log(1-tmp))
        return lik


####################
## Jaakkola nodes ##
####################

class Tau_Jaakkola(Node):
    """
    Add some description....
    """
    def __init__(self, dim, value):
        Node.__init__(self, dim=dim)

        if isinstance(value,(int,float)):
            self.value = value * s.ones(dim)
        else:
            assert value.shape == dim, "Dimensionality mismatch"
            self.value = value

    def updateExpectations(self):
        Zeta = self.markov_blanket["Y"].getParameters()["zeta"]
        self.value = 2*lambdafn(Zeta)

    def getValue(self):
        return self.value

    def getExpectation(self):
        return self.getValue()
        
    def getExpectations(self):
        return { 'E':self.getValue(), 'lnE':s.log(self.getValue()) }

    def removeFactors(self, idx, axis=None):
        pass
class Bernoulli_PseudoY_Jaakkola(PseudoY):
    """
    Class for a Bernoulli (0,1 data) pseudodata node with the following likelihood:
        p(y|x) = (e^{yx}) / (1+e^x) 
    Following Jaakola et al and intterpreting the bound as a liklihood on gaussian pseudodata
    leads to the folllowing updates

    Pseudodata is given by
            yhat_ij = (2*y_ij-1)/(4*lambadfn(xi_ij))
        where lambdafn(x)= tanh(x/2)/(4*x).
    
    Its conditional distribution is given by 
            N((ZW)_ij, 1/(2 lambadfn(xi_ij)))       
    
    Updates for the variational parameter xi_ij are given by
            sqrt(E((ZW)_ij^2))

    xi_ij in above notation is the same as zeta (variational parameter)         

    NOTE: For this class to work the noise variance tau needs to be updated according to 
        tau_ij <- 2*lambadfn(xi_ij)
    """
    def __init__(self, dim, obs, Zeta=None, E=None):
        PseudoY.__init__(self, dim=dim, obs=obs, Zeta=Zeta, E=E)

        # Initialise the observed data
        assert s.all( (self.obs==0) | (self.obs==1) ), "Data must be binary"

    def updateExpectations(self):
        self.E = (2.*self.obs - 1.)/(4.*lambdafn(self.Zeta))

    def updateParameters(self):
        Z = self.markov_blanket["Z"].getExpectations()
        SW = self.markov_blanket["SW"].getExpectations()
        self.Zeta = s.sqrt( s.square(Z["E"].dot(SW["E"].T)) - s.dot(s.square(Z["E"]),s.square(SW["E"].T)) + s.dot(Z["E2"], SW["ESWW"].T) )

    def calculateELBO(self):
        # Compute Lower Bound using the Bernoulli likelihood with observed data
        Z = self.markov_blanket["Z"].getExpectation()
        SW = self.markov_blanket["SW"].getExpectation()
        tmp = s.dot(Z,SW.T)
        lik = ma.sum( self.obs*tmp - s.log(1+s.exp(tmp)) )
        return lik