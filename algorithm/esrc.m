function accuracy = esrc(TrainSet, TestSet, train_num, test_num, class_num, lambda, options)
% Extended sparse representation classification (ESRC) algorithm
%
% Inputs:
%       TrainSet            train sets of size dxn, where d is dimension and n is number of sets 
%       TestSet             test sets of size dxn, where d is dimension and n is number of sets
%       test_num            numner of test sets
%       class_num           numner of classes
%       lambda              regularization paramter
% Output:
%       accuracy            classification accurary
%
% References:
%       W. Deng, J. Hu, and J. Guo, 
%       "Extended SRC: Undersampled face recognition via intraclass variant dictionary,"
%       IEEE Transation on Pattern Analysis Machine Intelligence, vol.34, no.9, pp.1864-1870, 2012.
%
%
% Created by H.Kasai on July 06, 2017


    % extract options
    if ~isfield(options, 'verbose')
        verbose = false;
    else
        verbose = options.verbose;
    end
    
    if ~isfield(options, 'eigenface')
        eigenface = true;
    else
        eigenface = options.eigenface;
    end    
    
    if ~isfield(options, 'eigenface_dim')
        eigenface_dim = train_num;
    else
        eigenface_dim = options.eigenface_dim;
    end     


    % generate intra-class variant dictionary (base)
    classes = unique(TrainSet.y); 
    dim = size(TrainSet.X, 1);
    TrainSet.D_I = zeros(dim, train_num);
    for j = 1 : class_num
        idx = find(TrainSet.y == classes(j)); 

        data = TrainSet.X(:, idx);
        centroid = sum(data,2)/size(data,2);

        % calculate logmap of centroid to each sample
        len = length(idx);
        for k = 1 : len
            diff = TrainSet.X(:, idx(k)) - centroid;                % Eq.(5)
            TrainSet.D_I(:, idx(k)) = real(diff);
        end

        if verbose
            fprintf('# Generating IntraVariDictionary for class %d\n', j);
        end
    end     

    % generate eigenface
    if eigenface    
        [disc_set, ~, ~]  =  Eigenface_f(TrainSet.X, eigenface_dim);
        
        % project on subspace
        TrainSet.X  =  disc_set' * TrainSet.X;
        TestSet.X   =  disc_set' * TestSet.X;
        TrainSet.D_I = disc_set' * TrainSet.D_I;
    end

    % normalize data to l2-norm
    [TrainSet.X, ~] = data_normalization(TrainSet.X, TrainSet.y, 'std');   
    [TestSet.X, ~] = data_normalization(TestSet.X, TestSet.y, 'std');  
    [TrainSet.D_I, ~] = data_normalization(TrainSet.D_I, TrainSet.y, 'std');  
    
    % combine train set and intra-class variation dictionary
    combined_X = [TrainSet.X TrainSet.D_I];

    % prepare class array
    classes = unique(TrainSet.y);
    
    % prepare predicted label array
    identity = zeros(1, test_num);
    
    for i = 1 : test_num

        y = TestSet.X(:, i);

        % calculate sparse code
        %xp = l1_ls(combined_X, y, lambda, 1e-3, 1); 
        param.lambda = lambda;
        param.lambda2 =  0; 
        param.mode = 2;
        alpha_beta = full(mexLasso(y, combined_X, param));          % Eq.(7)        

        % prepare residual array
        residuals = zeros(1, class_num);
        
        % calculate residual for each class
        for j = 1 : class_num
            non_idx = find(TrainSet.y ~= classes(j));
            sc = alpha_beta;
            sc(non_idx) = 0;
            residuals(j) = norm(y - combined_X*sc)/sum(sc.*sc);     % Eq.(8)
        end

        % calculate the predicted label with minimum residual
        [~, label] = min(residuals); 
        identity(i) = label;
        
        if verbose
            correct = (label == TestSet.y(1, i));
            fprintf('# ESRC: test:%03d, predict class: %03d --> ground truth :%03d (%d)\n', i, label, TestSet.y(1, i), correct);
        end           

    end

    % calculate accuracy
    correct_num = sum(identity == TestSet.y);
    accuracy = correct_num/test_num;
end



