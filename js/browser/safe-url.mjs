// The server's +safe-url: a root-relative path other than // or /\, or an
// https, mailto or tel URL, with no space or control byte, since browsers
// drop tabs and newlines inside a URL. Anything else is drawn as text and
// never followed.
export const safeUrl = url => !/[\0- \x7f]/.test(url) && /^(\/(?![/\\])|https:|mailto:|tel:)/.test(url);
