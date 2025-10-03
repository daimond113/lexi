type Split<S extends string, D extends string> = string extends S
    ? string[]
    : S extends ""
    ? []
    : S extends `${infer T}${D}${infer U}`
    ? [T, ...Split<U, D>]
    : [S];

type ExtractPlaceholders<T extends string> =
    T extends `${infer _Start}{${infer Placeholder}}${infer _End}`
    ? [Split<Placeholder, ":">, ...ExtractPlaceholders<_End>]
    : [];

type ParamKindToType = {
    int: number;
    fixed: number;
    num: number;
    HEX: number;
    hex: number;
    datetime: number;
    iso8601: number;
    shorttime: number;
    shortdatetime: number;
    shortdate: number;
    translate: string;
};

type ParamsToRecord<Params extends string[][]> = {
    [K in keyof Params as K extends `${number}`
    ? Params[K][0]
    : never]: Params[K] extends [infer _P, infer T]
    ? T extends keyof ParamKindToType
    ? ParamKindToType[T]
    : never
    : string;
};

interface Entries {
    [key: string]: string | Entries;
}

type RecurseEntries<E extends Entries> = {
    [K in keyof E]: E[K] extends string
    ? ExtractPlaceholders<E[K]> extends []
    ? () => string
    : (params: ParamsToRecord<ExtractPlaceholders<E[K]>>) => string
    : E[K] extends Entries
    ? RecurseEntries<E[K]>
    : never;
};

export function lexicon<const E extends Entries>(
    sourceLocale: string,
    entries: E,
): RecurseEntries<E>;
export function context<const S extends string>(source: S): (context: string) => S
