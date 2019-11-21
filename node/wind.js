const MIN_X = 512757;
const MAX_X = 864416;
const MIN_Y = 7213072;
const MAX_Y = 7689478;

const WIND_TYP = 5;
const WIND_MAX = 35;

const CONSUMPTION_TYP = 900;

const PRINT_MAX_X = 40;
const PRINT_MAX_Y = 50;

let neigh_k = 0.35;
let parent_k = 0.4;
let d_local_my_k = 0.05;
let d_local_sigma_k = 0.4;

let low_neigh_k = 0;
let low_parent_k = 1;
let low_d_local_my_k = 0;
let low_d_local_sigma_k = 0.05;

class Consumption {
    constructor() {
        this.typ = CONSUMPTION_TYP;
    }

    get() {
        return rayleigh(CONSUMPTION_TYP);
    }
}

class Level {
    constructor(
        scale,
        parent,
        neigh_k,
        parent_k,
        d_local_my_k,
        d_local_sigma_k,
        raster,
    ) {
        this.scale = scale;
        this.parent = parent;
        this.neigh_k = neigh_k;
        this.parent_k = parent_k;
        this.d_local_my_k = d_local_my_k;
        this.d_local_sigma_k = d_local_sigma_k;
        this.avg = 0;

        if (raster) {
            this.raster = raster;
        } else {
            this.raster = {};
            for (
                let x = floor(MIN_X, this.scale);
                x <= ceil(MAX_X, this.scale);
                x += this.scale
            ) {
                this.raster[x] = {};
                for (
                    let y = floor(MIN_Y, this.scale);
                    y <= ceil(MAX_Y, this.scale);
                    y += this.scale
                ) {
                    this.raster[x][y] = rayleigh(WIND_TYP);
                }
            }
        }
    }

    interpolate(x, y) {
        if (x % this.scale == 0 && y % this.scale == 0) {
            return this.raster[x][y];
        }

        let min_x = floor(x, this.scale);
        let max_x = ceil(x, this.scale);
        let min_y = floor(y, this.scale);
        let max_y = ceil(y, this.scale);

        let weight_minmin =
            1 / Math.sqrt(Math.pow(x - min_x, 2) + Math.pow(y - min_y, 2));
        let weight_minmax =
            1 / Math.sqrt(Math.pow(x - min_x, 2) + Math.pow(y - max_y, 2));
        let weight_maxmin =
            1 / Math.sqrt(Math.pow(x - max_x, 2) + Math.pow(y - min_y, 2));
        let weight_maxmax =
            1 / Math.sqrt(Math.pow(x - max_x, 2) + Math.pow(y - max_y, 2));
        let weight =
            weight_minmin + weight_minmax + weight_maxmin + weight_maxmax;

        let minmin, minmax, maxmin, maxmax;
        try {
            minmin = this.raster[min_x][min_y] * weight_minmin;
            minmax = this.raster[min_x][max_y] * weight_minmax;
            maxmin = this.raster[max_x][max_y] * weight_maxmin;
            maxmax = this.raster[max_x][max_y] * weight_maxmax;
        } catch (e) {
            return undefined;
        }

        return (minmin + minmax + maxmin + maxmax) / weight;
    }

    step() {
        let counter = 0;
        let sum = 0;
        for (
            let x = floor(MIN_X, this.scale);
            x <= ceil(MAX_X, this.scale);
            x += this.scale
        ) {
            for (
                let y = floor(MIN_Y, this.scale);
                y <= ceil(MAX_Y, this.scale);
                y += this.scale
            ) {
                let oldValue = this.raster[x][y];;
                let d_local_my =
                    - (oldValue - WIND_TYP) * this.d_local_my_k;
                let d_local_sigma = oldValue * this.d_local_sigma_k;
                let d_local = normal(d_local_my, d_local_sigma);

                let neighbours = this.neighbours(x, y, this);
                let neigh_mean = 0;
                if (neighbours.length == 0) {
                    neigh_mean = oldValue;
                } else {
                    for (neighbour of neighbours) {
                        neigh_mean += neighbour;
                    }
                    neigh_mean /= neighbours.length;
                }

                let parent_val;
                if (this.parent) {
                    parent_val = this.parent.interpolate(x, y);
                } else {
                    parent_val = oldValue;
                }

                this.raster[x][y] = oldValue
                    + d_local
                    + neigh_k * (neigh_mean - oldValue)
                    + parent_k * (parent_val - oldValue);
                
                counter++;
                sum += this.raster[x][y];

                if (this.raster[x][y] < 0) {
                    this.raster[x][y] = 0;
                } else if (this.raster[x][y] > WIND_MAX) {
                    this.raster[x][y] = WIND_MAX
                }
            }
        }
        this.avg = sum / counter;
    }

    print() {
        let counter_y = 0;
        for (
            let y = floor(MIN_Y, this.scale);
            y <= ceil(MAX_Y, this.scale) && counter_y < PRINT_MAX_Y;
            y += this.scale
        ) {
            counter_y++;
            let line = ""
            let counter_x = 0;
            for (
                let x = floor(MIN_X, this.scale);
                x <= ceil(MAX_X, this.scale) && counter_x < PRINT_MAX_X;
                x += this.scale
            ) {
                counter_x++;
                line += this.raster[x][y].toFixed(0).padStart(2, ' ') +  " ";
            }
            process.stdout.write(line + "\n");
        }
    }

    neighbours(x, y) {
        let min_x = x - this.scale;
        let max_x = x + this.scale;
        let min_y = y - this.scale;
        let max_y = y + this.scale;

        let neighbours = [];
        if (this.raster[x]) {
            neighbours.concat([
                this.raster[x][min_y],
                this.raster[x][max_y],
            ]);
        }

        if (this.raster[min_x]) {
            neighbours.concat([
                this.raster[min_x][min_y],
                this.raster[min_x][y],
                this.raster[min_x][max_y],
            ]).filter(Boolean);
        }

        if (this.raster[max_x]) {
            neighbours.concat([
                this.raster[max_x][min_y],
                this.raster[max_x][y],
                this.raster[max_x][max_y],
            ]).filter(Boolean);
        }

        return neighbours.filter(Boolean);
    }
}

class WindModel {
    constructor(frequency) {
        let level_100km = new Level(
            100000,
            null,
            neigh_k,
            parent_k,
            d_local_my_k,
            d_local_sigma_k,
        ); 
        let level_10km = new Level(
            10000,
            level_100km,
            neigh_k,
            parent_k,
            low_d_local_my_k,
            d_local_sigma_k,
        ); 
        let level_1km = new Level(
            1000,
            level_10km,
            low_neigh_k,
            low_parent_k,
            low_d_local_my_k,
            low_d_local_sigma_k,
        ); 

        this.frequency = frequency;
        this.levels = [level_100km, level_10km, level_1km];
        this.overview = level_10km;
        this.detailed = level_1km;
        this.typ = WIND_TYP;

        for (var i = 0; i < 10; i++) {
            this.levels.forEach((level) => {
                level.step();
            });
        }
    }

    get(x, y) {
        return this.detailed.interpolate(x, y);
    }

    avg() {
        return this.detailed.avg;
    }

    start(that) {
        if (!that) {
            that = this;
        }
        setTimeout(that.start, that.frequency, that);

        that.levels.forEach((level) => level.step());

        that.overview.print();
        process.stdout.write("\n");
    }
}

function floor(value, scale) {
    return Math.floor(value / scale) * scale;
}

function ceil(value, scale) {
    return Math.ceil(value / scale) * scale;
}

function rayleigh(sigma) {
    let rand = 0;
    while(rand === 0) rand = Math.random();
    return sigma * Math.sqrt(-2 * Math.log(rand));
}

function normal(my, sigma) {
    let u = 0, v = 0;
    while(u === 0) u = Math.random();
    while(v === 0) v = Math.random();
    let standard =
        Math.sqrt( -2.0 * Math.log( u ) ) * Math.cos( 2.0 * Math.PI * v );
    return standard * sigma + my
}

//function sample(model, x, y) {
//    setTimeout(sample, 2000, model, x, y);
//
//    console.log(model.get(x, y));
//}
//
//let windModel = new WindModel(2000);
//windModel.start();
//sample(windModel, 671333, 7294793);

module.exports = { WindModel, Consumption };