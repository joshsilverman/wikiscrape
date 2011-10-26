document.observe('dom:loaded', function() {
	intializeListeners();
});

var intializeListeners = function(){
	$$(".save").each(function(save){
		save.observe('click', function() {
			$("div_" + save.id).style.backgroundColor = "#BFFFC0";
		});
	});	
    $$(".field").each(function(field){
        field.observe('keypress', function() {
            $("div_" + field.getAttribute("topic_id")).style.backgroundColor = "#D6D6D6";
        });
    });
}

var saveTerm = function(topic_id) {
	$("div_" + topic_id).style.backgroundColor = "#BFFFC0";
    params = {"id" : topic_id};
	new Ajax.Request("/topics/", {
        method: 'post',
        parameters: params,
        onFailure: function() {
        	$("div_" + topic_id).style.backgroundColor = "#D6D6D6";
            alert("Save failed!");
        },
        onSuccess: function() {
        	alert("success");
 //        	callback_params = {"term_id" : term_id};
 //        	new Ajax.Request('/topics/get_topic', {
	// 	        method: 'post',
	// 	        parameters: callback_params,
	// 	        onFailure: function() {
	// 	            alert("Update failed!");
	// 	        },
	// 	        onSuccess: function(response) {
	// 	        	var response = JSON.parse(response.request.transport.responseText)
	// 	        	$('title_' + dom_id).value = response.topic.topic.name
	// 	        	$('description_' + dom_id).value = response.topic.topic.description;
	// 	   			$('question_' + dom_id).value = response.topic.topic.question;
	// 	   		   	var answerText = "";
	// 	   			response.answers.each(function(answer) {
	// 	   				answerText = answerText + answer.answer.name + "\n";
	// 	   			});
	// 	   			$('answers_' + dom_id).value = answerText;

	// 	        	// UPDATE LINKS, ETC
 //        		}.bind(this)
 //        	});
        }.bind(this)
    });
}

var reloadTerm = function(dom_id, term_id, doc_id) {
    var term = $("title_" + dom_id).value;
	$("div_" + dom_id).style.backgroundColor = "#D6D6D6";
	params = { "term" : term, 
		"term_id" : term_id,
		"doc_id" : doc_id
    };	
	new Ajax.Request('/documents/reload_term', {
        method: 'post',
        parameters: params,
        onFailure: function() {
            alert("Sorry, update failed.");
        },
        onSuccess: function(response) {
        	callback_params = {"term_id" : term_id, "term" : term};
        	new Ajax.Request('/topics/get_topic', {
		        method: 'post',
		        parameters: callback_params,
		        onFailure: function() {
		            alert("Sorry, update failed.");
		        },
		        onSuccess: function(response) {
		            var response = JSON.parse(response.request.transport.responseText)
    	        	$('title_' + dom_id).value = response.topic.topic.name
    	        	$('description_' + dom_id).value = response.topic.topic.description;
    	   			$('question_' + dom_id).value = response.topic.topic.question;
    	   		   	var answerText = "";
    	   			response.answers.each(function(answer) {
    	   				answerText = answerText + answer.answer.name + "\n";
    	   			});
    	   			$('answers_' + dom_id).value = answerText;

		      //   	// UPDATE LINKS, ETC
        		}.bind(this)
        	});
        }.bind(this)
    });
}