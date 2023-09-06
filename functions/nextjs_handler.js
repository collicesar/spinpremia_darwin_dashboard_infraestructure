var hasExtension = /(.+)\.[a-zA-Z0-9]{2,5}$/;
var hasSlash = /\/$/;

function handler(event) {
    var request = event.request;
    var uri = request.uri;
    if (uri && !uri.match(hasExtension) && !uri.match(hasSlash)) {
      request.uri = `${uri}.html`;
    }
    return request;
}