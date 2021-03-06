function [ modelCollection,numSS, Labels] = pcStream_IPCA( X, phi, t_min, Pvar, initModelSize)
% Matlab implimentation of pcStream with IPCA. Please cite:
% Mirsky, Y., Halpern, T., Upadhyay, R. and Toledo, S., 2016
% Enhanced Situation Space Mining for Data Streams, the 32nd ACM Symposium on Applied Computing

%Input:
% X is a m-by-n matrix with m instances and n feature dimensions.
% phi is the (max score) to detect a drifting instance
% t_min is the number of consequtive drifters needed to trigger a new
% Pvar is the percent of variance to retain in each model (e.g. 0.98)
% modelMemSize is the number of instaces to retain in each model's memory buffer
% initModelSize, is the number of instaces to take from the start of X to initilize the firt model (e.g., t_min + 1)

%Output:
% modelCollection is a cell collection of the models which each capture a situationspace detected from X. 
% numSS is the number of situation spaces detect (the size of the modelCollection)
% Labels the Situation space IDs assigned to each instace in X as they arrive. Note, this algorithm is a one-pass online algorithm. 

% init
dim = size(X,2); %dimensionality of the dataset
maxModels = 1000; %no new models will be added to the modelCollection if more than maxModels are detected
modelCollection = cell(1,maxModels);
numSS = 0;
driftBuffer = zeros(t_min,dim);
numDrifters = 0;
Labels = zeros(size(X,1),1);
numTics = size(X,1);

% Initial model
len = initModelSize;
if initModelSize < t_min + 1
    len = mint_t + 1; %ensure rank for pca
end
numSS = numSS + 1;
modelCollection{numSS} = ModelSituationSpace_pcS_IPCA(X(1:len,:),Pvar);
Labels(1:len) = 1;
LabelCounter = len+1;
CurMdl = 1;

tic
for t = (len+1):numTics 
     if mod(t,1000)==0
         display(['t:' num2str(t) ' num Situation Spaces:' num2str(numSS) ' BlockTime:' num2str(toc)]);
         tic
     end
     
    %Calculate Mahalanobis distance of current instace to all known situation spaces
    scores = zeros(1,numSS);
    for i = 1:numSS
        %convert X to the  from standard basis to new one:
        Xtag = (X(t,:)-modelCollection{i}.centroid); % the points after zero-meaned
        transPoint = Xtag*modelCollection{i}.coeff;
        scores(i) = transPoint*transPoint';
    end
    scores = sqrt(scores);
    
    %Find the closest situation space
    [~,bestMdl] = min(scores);
    
    %Before assinging this observation to a situation space...
    %Detect drift (i.e., perhaps this observation does not belong to any
    %situation space)
    if min(scores) > phi
       % Add the drifter to a buffer
       numDrifters = numDrifters + 1;
       driftBuffer(numDrifters,:) = X(t,:);
       
       %Check if the buffer is full (i.e., contains a new situation space)
       if numDrifters >= t_min
           if rank(driftBuffer(1:numDrifters,:)) > 1
               % Make new model based on the bufferd instances
               numSS = numSS+1;
               modelCollection{numSS} = ModelSituationSpace_pcS_IPCA(driftBuffer,Pvar);
               Labels(LabelCounter:(LabelCounter+t_min-1)) = numSS; % assign labels to these instances
               LabelCounter = LabelCounter + numDrifters;
               CurMdl = numSS; %update the current model to this new one

               % Clear the buffer
               driftBuffer = zeros(t_min,dim);
               numDrifters = 0;
           end
       end
    else %there was no new situation space detected, so empy the buffer into nearest model
        if numDrifters > 0
            modelCollection{CurMdl} = UpdateSituationSpace_pcS_IPCA(driftBuffer(1:numDrifters,:),modelCollection{CurMdl});
            Labels(LabelCounter:(LabelCounter+numDrifters-1)) = CurMdl;
            LabelCounter = LabelCounter +numDrifters;

           % Clear the buffer
           driftBuffer = zeros(t_min,dim);
           numDrifters = 0;
        end
        
        % Assign current instance to the closest situation space (update that model)
        modelCollection{bestMdl} = UpdateSituationSpace_pcS_IPCA(X(t,:),modelCollection{bestMdl});
        
        Labels(LabelCounter) = bestMdl;
        LabelCounter=LabelCounter+1;
        CurMdl = bestMdl; %set the "current" model to this model
    end
end

% Done. but empy the drift buffer to we cat get all labels:
if numDrifters > 0
            modelCollection{CurMdl} = UpdateSituationSpace_pcS_IPCA(driftBuffer(1:numDrifters,:),modelCollection{CurMdl});
            Labels(LabelCounter:(LabelCounter+numDrifters-1)) = CurMdl;
            LabelCounter = LabelCounter + numDrifters;
end
modelCollection = modelCollection(1:numSS);

end

