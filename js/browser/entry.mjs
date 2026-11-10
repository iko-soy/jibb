// The browser library's entry: a page with islands loads it as a module.
import { boot } from './boot.mjs';

boot().catch(error => console.error('jibb: the islands could not start', error));
