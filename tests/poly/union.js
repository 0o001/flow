type Filter = [number] | [string];

function convert(filter: Filter) {
    filter.slice(0);
}

type Filter2 = Array<number> | Array<string>;

function convert2(filter: Filter2) : Filter2 {
    return filter.slice(0);
}
